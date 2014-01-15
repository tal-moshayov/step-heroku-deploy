# Heroku deployment step

Deploy your code to Heroku. This step requires that you deploy to a Heroku deploy target. 

# Using wercker SSH key pair

To push to Heroku we need to have a ssh key. We can dynamically generate a key, add the key to your repository and then remove it, during each build. But this results in a e-mail from Heroku on each deploy. 

To prevent this you can generate a private/public key pair on wercker and manually add the public key to Heroku.

- Generate a new key in wercker in the `Key management` section (`application` - `settings`).
- Copy the public key and add it in Heroku to the `SSH Keys section` section (`account`).
- In wercker edit the Heroku deploy target to which you would like to deploy and add a environment variable:
    - Give the environment variable a name (remember this name, you will need it in the last step).
    - Select `SSH Key pair` as the type and select the key pair which you created earlier.
- In the `heroku-deploy` step in your `wercker.yml` add the `key-name` property with the value you used earlier:

``` yaml
deploy:
    steps:
        - heroku-deploy:
            key-name: MY_DEPLOY_KEY
```

In the above example the `MY_DEPLOY_KEY` should match the environment variable name you used in wercker. Note: you should not prefix it with a dollar sign or post fix it with `_PRIVATE` or `_PUBLIC`.

# What's new

* Update README, to clearify using a SSH Key pair.

# Options

* `key-name` (optional) Specify the name of the key that should be used for this deployment. If left empty, a temporary key will be created for the deployment.
* `retry` (optional) When a deploy to Heroku fails, a new deploy is automatically performed after 5 seconds. If you want to disable this behavior, set `retry` to `false`.
* `run` (optional) Run a command on heroku after the code is deployed succesfully. This option can be used to migrate the database for example.

# Example

``` yaml
deploy:
    steps:
        - heroku-deploy:
            key-name: MY_DEPLOY_KEY
```

# License

The MIT License (MIT)

# Changelog

## 1.0.5

* Update README, to clearify using a SSH Key pair.

## 1.0.4

* Fixed release that also works on ruby based boxes (always installs ruby 1.9.1)

## 1.0.1

* fix for apt-get bug: deb files are now included [broken]

## 1.0.0

* Bug fixes

## 0.0.9-dev

* Adds `run` option.

## 0.0.8

* Retry on failure.

## 0.0.7

* Only call `heroku keys:remove` if a ephemeral key was used (wercker/step-heroku-deploy#2).
* Update README.

## 0.0.6

* Fix wrong option check.

## 0.0.4

* Added validation to `key-name` option.

## 0.0.3

* Added `key-name` option.

## 0.0.2

* Initial release.
