#### `xcodebuild test` does not run properly.

If run via SSH, `xcodebuild test` will not have access to the OS X GUI environment and will not work properly.

If you are using Jenkins, you need to run the slave via JNLP, not via SSH. And on the CI machine, the JNLP client must be run as a LaunchAgent.

#### Xcode is not able to sign my application.

First you need to make sure your application signing credentials are installed on the CI machine. Try building your application on it using the normal Xcode.

If you are able to build the application with Xcode but not Dokumi, you might want to try to run the following commands before every Dokumi run.

```shell
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN}"
security set-keychain-settings -l -t 1800
```

with `KEYCHAIN` being set to the name of the keychain containing the credentials ("login.keychain" by default), and `KEYCHAIN_PASSWORD` the password for that keychain.

### What is `xcodebuild` error 65?

This error code itself does not mean much, just that an error occurred while running `xcodebuild`. Dokumi tries finding errors in the `xcodebuild` output, but if it could not find any, and `xcodebuild` ends with a non-zero error code, Dokumi will tell you that `xcodebuild` error code and exit.

So it is very likely you have found a bug: an error type that Dokumi does not catch yet.

### Why is the full `xcodebuild` output not printed directly?

Because it is way too big, you easily end up with tens of megabytes of log for each `xcodebuild` run.

### Why are you not using `xctool`?

- Using `xctool` does not make it easier to find errors and warnings in the `xcodebuild` logs.
- The way `xctool` works seems pretty brittle (it injects code into `xcodebuild`).

### Can I use a different development team for signing applications built with Dokumi?

Yes, but it is a bit messy, especially if you are using app groups.

The easy part is to change the development team and code signing identity of the project:

```ruby
xcode.modify_project project_path do |project|
  project.development_team = DEVELOPMENT_TEAM
  project.code_signing_identity = CODE_SIGNING_IDENTITY
  project.provisioning_profile = "" # in Xcode displayed as "Automatic"
end
```

Unfortunately in many cases that is not enough. You may also have to update the entitlements, bundle id, the Watch app bundle id if you support the Apple Watch.

Having wildcard provisioning profiles makes things easier, but it seems you cannot use them when using app groups.

```ruby
xcode.modify_project project_path do |project|
  # Updating app groups is of course only needed if you use them. (You probably do if you support the Apple Watch.)
  project.update_entitlements do |entitlement|
    entitlement.update_application_groups {|current_app_group_name| fix_app_group(current_app_group_name) }
  end

  project.update_info_plists do |info_plist|
    info_plist.update_bundle_identifier {|bundle_id| fix_bundle_id(bundle_id) }
    # Only if you support the Apple Watch.
    info_plist.update_watch_app_bundle_identifier_if_present {|bundle_id| fix_watch_bundle_id(bundle_id) }
  end
end
```

If you are using app groups, you also need to make sure that you use the renamed app groups in the code. You can do that either by using `#ifdef`s (and a `-D` only used in the Dokumi builds), or modifying directly the source code in your Dokumi build script.

#### I'm using Fabric/Crashlytics and I can't see the crashes from applications built with Dokumi in the dashboard.

It might seem strange but make sure that Fabric.app (and Crashlytics.app) are *not* installed on the CI machine.
