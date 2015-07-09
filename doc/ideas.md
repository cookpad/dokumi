Just some random ideas to improve Dokumi, in no particular order.

- Maybe not depend on something like Jenkins, but make Dokumi have its own job system (using for example Resque). This would allow to have more control, and for example not create a new job for a pull request when a job for that pull request is already waiting. Also without having a server accessible from the GitHub server, you could poll regularly and easily create jobs when a pull request has been added.
- Use a default simulator destination when the user doesn't specify it in the build file, depending on the Xcode version used.
- A review only ends in error when an error was found. We should maybe exit in error for a warning on a line directly modified by the pull request.
- Log handling is not consistent. Ideas of what could be done:
  - Don't use `puts`, but a real logging system.
  - Add time to each log line. That would allow to easily see what took too much time.
  - The `xcodebuild` logs are too big to be logged with the rest, but they are currently removed before every new build. We should compress them and keep at least the last 20 or so.
- More and better documentation would be nice.
- Add a way to better manage artifacts.
- Add support to check if a pull request respects coding rules (indentation, spacing, naming).
- On Xcode 7 build and run the tests with Address Sanitizer turned on.
- Maybe add support for using Facebook Infer.
- Get the commit id from the reference at the start (from the pull request info we got from GitHub), and use that it instead of the reference (as the last commit might have changed behind our back).
- It seems that the code to avoid posting duplicated comments when testing multiple time the same pull request sometimes does not work properly, need to investigate.
- Report a warning for modified source files that do not end with \n.
- Currently for managing the `custom/` directory, you need to not forget to create your own repository and not forget to pull it at every change. Maybe make it more automatic and/or display an error is `custom/` does not contain a repository.
- Maybe have a default way for a repository to choose the version of Xcode to use for the build. It is easy to add a `dokumi-xcode.yml` file in each repository and read it from the build script, but having it by default would probably make things even easier.
- Make it possible to have a build script inside an applications's repository. The problem is that that requires a fixed API, making it harder to modify Dokumi itself. The best would probably be to split the version control-related part and the build tools part. The version control-related part would have its API fixed, and a build script would be able to specify what version of the tools it wants to use.
