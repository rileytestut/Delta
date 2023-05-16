Thank you for your interest in contributing to Delta! Delta is an open-source project that aims to provide a seamless and enjoyable experience for playing classic video games on iOS devices. We welcome contributions from anyone who shares our vision and passion for emulation.

# How to Contribute

We are currently accepting these types of contributions for Delta:

- Experimental Features
- Bug fixes

All features added by third-party contributors will be considered *experimental* at first, and are disabled by default unless specifically enabled by the user from the Experimental Features section in Delta's settings. Experimental Features are only available in the beta version of Delta, but once a feature has been sufficiently tested we may choose to "graduate" it into an official Delta feature, at which point it will become available to all users.

For more specific instructions regarding contributing features to Delta, see [ExperimentalFeatures.md](Docs/ExperimentalFeatures.md).

> Make sure to use the `develop` branch as the base branch for all Pull Requests.

## Contribution Guidelines

**Check out our project board first!**  
We have categorized issues and pull requests to highlight areas where help is most needed. You are welcome to contribute something new, but keep in mind that we may focus on more highly-requested items first.

**Keep changes small**  
The smaller a pull request is the more likely it will be merged. Make sure your PRs are limited to just the relevant changes and nothing else. Avoid pure formatting changes to code that has not been modified otherwise.

**Make sure contributions are 100% complete**  
We can't accept unfinished pull requests, so please make sure your contribution is ready to be merged as-is.

**Extensively test your changes**  
Make sure your changes work as expected on different devices and iOS versions, and doesn't result in additional bugs.
  
**Commit only relevant changes of changed files**  
Some files, such as Storyboards and Xcode projects, often contain changes that are unrelated to your specific change. **You should almost never commit an entire Storyboard or Xcode project as-is.**

**Not all contributions will be accepted**  
To maximize your chances of getting your pull request accepted, make sure to read all the guidelines carefully and familiarize yourself with the project structure, coding style, and best practices. 

## Code Style and Conventions

**Please make sure your code follows these guidelines and is free of compiler warnings before submitting a pull request.**

* All contributions should be pure Swift, no C++ or Objective-C (unless absolutely necessary)

* Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) for writing clean, consistent, and expressive Swift code

* Use Allman (a.k.a. brackets on new line) brace style (exceptions: closures and single-line statements)

* Use 4 spaces for indentation. Do not use tabs or mix tabs and spaces.

* Use whitespace liberally to make code easier to read

* Use descriptive variable names

* Lean on the side of commenting (more comments make it more likely to be approved)

* Prefer structs over classes. Classes should be used only if you need a reference type, or to interoperate with ObjC.

When editing existing code, please preserve the original formatting of the code as much as possible (e.g. brace style). Do not make unnecessary changes to whitespace, indentation, line breaks or comments. This helps keep the diffs clean and easy to review.

For example, when editing code that uses the Allman brace style (a.k.a. brackets on new line), make sure any `if`/`else` statements you write also place the bracket on a new line. 
  
## Submitting Pull Requests

All pull requests must adhere to the PR template, filling out each section as appropriate. **Only PRs that follow this template will be accepted.**

Once you've submitted your PR, we will review it and provide feedback as soon as we can.
