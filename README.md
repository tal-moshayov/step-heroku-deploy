# Heroku deployment step

Deploy your code to Heroku. This step requires that you deploy to a Heroku deploy target. 

You can optionally use a wercker ssh key (using `key-name`), which is highly recommended.

# What's new

* Adds `run` option.
* Update README.

# Options

* `key-name` (optional) Specify the name of the key that should be used for this deployment. If left empty, a temporary key will be created for the deployment.
* `retry` (optional) When a deploy to Heroku fails, a new deploy is automatically performed after 5 seconds. If you want to disable this behavior, set `retry` to `false`.
* `run` (optional) Run a command on heroku after the code is deployed succesfully. This option can be used to migrate the database for example.

# Example

``` yaml
- heroku-deploy:
    - key-name: MY_DEPLOY_KEY
```

# License

The MIT License (MIT)

# Changelog

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
