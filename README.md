# Heroku deployment step

The step assumes you have a heroku deployment target configured in wercker.

## What is new?

* Fix wrong option check.

# Options

## key-name

* type: string
* optional: true (default: `empty`, which means this step will generate a new key and adds it to heroku via the api.)
* description: specify the name of the key that should be used for this deployment.

# Example

``` yaml
- heroku-deploy:
    - key-name: MY_DEPLOY_KEY
````

# History

* `0.0.5` - Fix wrong option check.
* `0.0.4` - Added validation to `key-name` option.
* `0.0.3` - Added `key-name` option.
* `0.0.2` - Initial release
