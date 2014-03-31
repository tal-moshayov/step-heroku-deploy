# Suffix for missing options.
error_suffix='Please add this option to the wercker.yml or add a heroku deployment target on the website which will set these options for you.'
exit_code_push=0
exit_code_run=0

if [ -z "$WERCKER_HEROKU_DEPLOY_KEY"  ]
then
    if [ ! -z "$HEROKU_KEY" ]
    then
        export WERCKER_HEROKU_DEPLOY_KEY="$HEROKU_KEY"
    else
        fail "Missing or empty option heroku_key. $error_suffix"
    fi
fi

if [ -z "$WERCKER_HEROKU_DEPLOY_APP_NAME" ]
then
    if [ ! -z "$HEROKU_APP_NAME" ]
    then
        export WERCKER_HEROKU_DEPLOY_APP_NAME="$HEROKU_APP_NAME"
    else
        fail "Missing or empty option heroku_app_name. $error_suffix"
    fi
fi

if [ -z "$WERCKER_HEROKU_DEPLOY_USER" ]
then
    if [ ! -z "$HEROKU_USER" ]
    then
        export WERCKER_HEROKU_DEPLOY_USER="$HEROKU_USER"
    else
        export WERCKER_HEROKU_DEPLOY_USER="heroku-deploy@wercker.com"
    fi
fi

if [ -z "$WERCKER_HEROKU_DEPLOY_SOURCE_DIR" ]
then
    export WERCKER_HEROKU_DEPLOY_SOURCE_DIR=$WERCKER_ROOT
    debug "Option source_dir not set. Will deploy directory $WERCKER_HEROKU_DEPLOY_SOURCE_DIR"
else
    debug "Option source_dir found. Will deploy directory $WERCKER_HEROKU_DEPLOY_SOURCE_DIR"
fi

# Install heroku toolbelt if needed
if ! type heroku &> /dev/null ;
then
    info 'heroku toolbelt not found, starting installing it'

    cd $TMPDIR
    # result=$(sudo wget -qO- https://toolbelt.heroku.com/install-ubuntu.sh | sh)

    sudo apt-get update
    sudo apt-get install -y ruby1.9.1 git-core
    result=$(sudo dpkg -i $WERCKER_STEP_ROOT/foreman-0.60.0.deb $WERCKER_STEP_ROOT/heroku-3.2.0.deb $WERCKER_STEP_ROOT/heroku-toolbelt-3.2.0.deb)

    if [[ $? -ne 0 ]];then
        warning $result
        fail 'heroku toolbelt installation failed';
    else
        info 'finished heroku toolbelt installation';
    fi
else
    info 'heroku toolbelt is available, and will not be installed by this step'
    debug "type heroku: $(type heroku)"
    debug "heroku version: $(heroku --version)"
fi

curl -H "Accept: application/json" -u :$WERCKER_HEROKU_DEPLOY_KEY https://api.heroku.com/apps/$WERCKER_HEROKU_DEPLOY_APP_NAME
echo "machine api.heroku.com" > /home/ubuntu/.netrc
echo "  login $WERCKER_HEROKU_DEPLOY_USER" >> /home/ubuntu/.netrc
echo "  password $WERCKER_HEROKU_DEPLOY_KEY" >> /home/ubuntu/.netrc
chmod 0600 /home/ubuntu/.netrc
git config --global user.name "$WERCKER_HEROKU_DEPLOY_USER"
git config --global user.email "$WERCKER_HEROKU_DEPLOY_USER"
cd
mkdir -p key
chmod 0700 ./key
cd key

if [ -n "$WERCKER_HEROKU_DEPLOY_KEY_NAME" ]
then
    debug "will use specified key in key-name option: $WERCKER_HEROKU_DEPLOY_KEY_NAME"

    export key_file_name="$WERCKER_HEROKU_DEPLOY_KEY_NAME"
    export privateKey=$(eval echo "\$${WERCKER_HEROKU_DEPLOY_KEY_NAME}_PRIVATE")

    if [ ! -n "$privateKey" ]
    then
        fail 'Missing key error. The key-name is specified, but no key with this name could be found. Make sure you generated an key, *and* exported it as an environment variable.'
    fi

    debug "Writing key file to $key_file_name"
    echo -e "$privateKey" > $key_file_name
    chmod 0600 "$key_file_name"
else
    debug "no key-name specified, will generate key and add it to heroku"

    #Generate random key to prevent naming collision
    # This key will only be used for this deployment
    export key_file_name="deploy-$RANDOM"
    export key_name="$key_file_name@wercker.com"
    debug 'generating random ssh key for this deploy'
    ssh-keygen -f "$key_file_name" -C "$key_name" -N '' -t rsa -q
    debug "generated ssh key $key_name for this deployment"
    chmod 0600 "$key_file_name"

    # Add key to heroku
    heroku keys:add "/home/ubuntu/key/$key_file_name.pub"
    debug "added ssh key $key_file_name.pub to heroku"
fi

echo "ssh -e none -i \"/home/ubuntu/key/$key_file_name\" -o \"StrictHostKeyChecking no\" \$@" > gitssh
chmod 0700 /home/ubuntu/key/gitssh
export GIT_SSH=/home/ubuntu/key/gitssh
cd $WERCKER_HEROKU_DEPLOY_SOURCE_DIR || fail "could not change directory to source_dir \"$WERCKER_HEROKU_DEPLOY_SOURCE_DIR\""
heroku version

#if true, we keep the repository in its state.
if [ "$WERCKER_HEROKU_DEPLOY_KEEP_REPOSITORY" == "true" ]
then
    debug "keeping git repository"
    if [ -d '.git' ]; then
        debug "found git repository in $(pwd)"
    else
        fail "no git repository found to push"
    fi

    git checkout $WERCKER_GIT_BRANCH
else
    # If there is a git repository, remove it because
    # we want to create a new git repository to push
    # to heroku.
    if [ -d '.git' ]
    then
        debug "found git repository in $(pwd)"
        warn "Removing git repository from $WERCKER_ROOT"
        rm -rf '.git'
        #submodules found are flattened
        if [ -f '.gitmodules' ]
        then
            debug "found possible git submodule(s) usage"
            while IFS= read -r -d '' file
            do
                rm -f "$file" && warn "Removed submodule $file"
            done < <(find "$WERCKER_HEROKU_DEPLOY_SOURCE_DIR" -type f -name ".git" -print0)
        fi
    fi

    # Create git repository and add all files.
    # This repository will get pushed to heroku.
    git init
    git add .
    git commit -m 'wercker deploy'
fi

# Deploy with a git push
set +e
debug "starting heroku deployment with git push"
git push -f git@heroku.com:$WERCKER_HEROKU_DEPLOY_APP_NAME.git HEAD:master
exit_code_push=$?

debug "git pushed exited with $exit_code_push"

if [ $exit_code_push -ne 0 ]
then
    if [ "$WERCKER_HEROKU_DEPLOY_RETRY" == "false" ]; then
    	warn "don't retry deployment"
    else
        info "retry heroku deployment with git push after 5 seconds"
        sleep 5

        git push -f git@heroku.com:$WERCKER_HEROKU_DEPLOY_APP_NAME.git HEAD:master
        exit_code_push=$?

        debug "git push retry exited with $exit_code_push"
    fi
fi

if [ -n "$WERCKER_HEROKU_DEPLOY_RUN" ]
then
    run_command="$WERCKER_HEROKU_DEPLOY_RUN"

    debug "starting heroku run $run_command"
    heroku run "$run_command" --app $HEROKU_APP_NAME
    exit_code_run=$?
fi

# Cleanup ssh key
if [ -z "$WERCKER_HEROKU_DEPLOY_KEY_NAME" ]
then
    heroku keys:remove "$key_name"
    debug "removed ssh key $key_name from heroku"
fi

# Validate git run
if [ $exit_code_run -ne 0 ]
then
    fail 'heroku run failed'
fi

# Validate git push deploy
if [ $exit_code_push -eq 0 ]
then
    success 'deployment to heroku finished successfully'
else
    fail 'git push to heroku failed'
fi
