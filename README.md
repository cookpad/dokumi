Dokumi
======

Dokumi is a tool created to automatically check if anything is wrong with the code in a pull request. More details in the following blog article:

- [Dokumi (English)](http://techlife.cookpad.com/entry/2015/06/04/dokumi-en)
- [Dokumi (日本語)](http://techlife.cookpad.com/entry/2015/06/04/dokumi-ja)

Automatic code review is its main feature, but it can also be used to automatically build an application an send it to a service like DeployGate or HockeyApp.

As explained in the LICENSE file, Dokumi is under the MIT license.

How to set it up
----------------

### Requirements

- Ruby 2.0 or better (it might work with 1.9) with bundler installed.
- For building an application with Xcode, the machine running Dokumi must be running OS X and have Xcode installed.
- The machine running Dokumi must be able to clone repositories from the GitHub server.

### Environment setup

The GitHub Enterprise settings are in `config/github.yml`. You should start with `config/github.yml.sample`. You can easily create an access token in your GitHub's profile settings, in "Personal access tokens" (depending on your version of GitHub, "Personal access tokens" might be in "Applications"). That token should be able to get information about repositories and post comments in issues and pull requests. For testing purpose, using you personal account is fine, but I highly recommend you create a different account for your CI, as the comments posted by Dokumi will be under the name of the account used to create the token.

For projects using Xcode, there is also a `config/xcode_versions.yml` settings file for specifying the Xcode versions you have installed on your machine. It will be generated with default settings the first time you do an Xcode build, but you can also create your own starting from `config/xcode_versions.yml.sample`. Once this settings file is created, changing the system's default Xcode using `xcode-select` will not change the path to the version of Xcode used.

For Android projects, you also have a `android.yml` settings file.

To check if your environment is set-up properly, you can first try [running the tests](#run_tests) before making your own build script.

### Build scripts

Once the environment setup is done, you need a script to build your application and review the pull requests. For that, first create a `custom/build` directory. I highly recommend you create a Git repository for managing the content of your `custom` directory.

When reviewing or building your code, Dokumi will first clone the repository into `source/host/owner/repo` (host, owner and repo will be of course the host, owner and the name of the repository). Then it will search for the build script for that repository. It will first look for `custom/build/host/owner/repo.rb`, and if it does not exist it will try using `custom/build/host/fallback.rb` and then try `custom/build/fallback.rb`.

Here is a sample build script: (you need of course to change the value of `to_build` and also maybe `scheme`)
```ruby
to_build = "MyProject.xcworkspace"
scheme = "MyProject" # In Xcode the scheme must have been marked as shared.

xcode.install_pods if File.exist?("Podfile") # Not needed if the content of your Pods directory is stored in the repository.

case action
when :review
  xcode.find_unchanged_storyboards
  xcode.analyze to_build, scheme: scheme
  unless error_found?
    xcode.test(to_build, scheme: scheme, destination: [
      "platform=iOS Simulator,OS=8.4,name=iPhone 4s",
      "platform=iOS Simulator,OS=8.4,name=iPhone 6",
    ])
  end
when :archive
  xcode.archive to_build, scheme: scheme
  artifacts.each do |artifact_path|
    Support.logger.info "#{artifact_path} should be uploaded or copied somewhere"
  end
else
  raise "unknown action #{action.inspect}"
end
```

`action` correspond to the command used to run Dokumi: either `:review` or `:archive`. The script also has access to the options given to the command line in the `options` hash (its keys are symbols).

For more information about build scripts, have a look at `doc/about_build_scripts.md`.

If you have a problem, have a look at `doc/FAQ.md`.

How to run it
-------------

First you need to make sure you have all the required gems installed:
```
bundle install
```

Then to review a pull request:
```
bundle exec bin/review https://host/owner/repo/pull/xxx --option1=value1 --option2=value2 ...
```

or

```
bundle exec bin/review host owner repo pull-request-number --option1=value1 --option2=value2 ...
```

The host can be of course github.com.

option1, option2 are optional.

To build an application you also have the `bin/archive` command.

Run the tests <a name="run_tests"></a>
-------------

First you need to make sure you have all the required gems installed:
```
bundle install
```

Then to run the iOS tests:
```
bundle exec test/review_xcode_project.rb
```

Supported analysis tools
-----------------------

### iOS

- [xcodebuild](https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man1/xcodebuild.1.html)

### Android

- [Findbugs](https://docs.gradle.org/current/dsl/org.gradle.api.plugins.quality.FindBugs.html)
- [Infer](http://fbinfer.com/)

How to use Dokumi with Jenkins
------------------------------

If you are using the GitHub pull request builder plugin, making it executing the following might be enough:
```shell
set -e
DOKUMI_DIRECTORY=/path/to/dokumi

cd "${DOKUMI_DIRECTORY}"
bundle exec bin/review "${ghprbPullLink}"
```
with DOKUMI_DIRECTORY set to the proper path.

If you have any signing problem, have a look at doc/FAQ.md.
