# Suffix for missing options.
error_suffix='Please add this option to the wercker.yml or add a heroku deployment target on the website which will set these options for you.'

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
    result=$(sudo wget -qO- https://toolbelt.heroku.com/install-ubuntu.sh | sh)

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

if [ ! -n "$WERCKER_HEROKU_KEY_NAME" ]
then
    debug "will use specified key in key-name option"

    export key_file_name="$WERCKER_HEROKU_KEY_NAME"
    export privateKey=$(eval echo "\$${WERCKER_HEROKU_KEY_NAME}_PRIVATE")

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

# If there is a git repository, remove it because
# we want to create a new git repository to push
# to heroku.
if [ -d '.git' ]
then
    debug "found git repository in $(pwd)"
    warn "Removing git repository from $WERCKER_ROOT"
    rm -rf '.git'
fi

# Create git repository and add all files.
# This repository will get pushed to heroku.
git init
git add .
git commit -m 'wercker deploy'

# Deploy with a git push
debug "starting heroku deployment with git push"
git push -f git@heroku.com:$WERCKER_HEROKU_DEPLOY_APP_NAME.git master
exit_code=$?

debug "git pushed exited with $exit_code"

# Cleanup ssh key
heroku keys:remove "$key_name"
debug "removed ssh key $key_name from heroku"

# Validate git push deploy
if [ $exit_code -eq 0 ]
then
    success 'deployment to heroku finished successfully'
else
    fail 'git push to heroku failed'
fi
