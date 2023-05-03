Mark the type contribution you are making:

- [ ] Experimental feature (new functionality that can be selectively enabled/disabled)
- [ ] Bug fix (non-breaking change which fixes an issue)

# Description

Summary of your changes, including: 

* Why is this change necessary?
* Why did you decide on this solution?

# Testing

List all iOS versions and devices you've tested this change on.

**Example Configurations**:

- iPhone 14, iOS 16.3.1
- iPhone X, iOS 15.7.4

# Checklist
**General (All PRs)**
- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] My changes generate no new warnings
- [ ] I've tested my changes with different device + OS version configurations

**Experimental Feature-specific** 
- [ ] Added property to `ExperimentalFeatures` struct annotated with `@Feature`
- [ ] Uses `@Option`'s to persist all feature-related data
- [ ] Locked *all* behavior changes behind `ExperimentalFeatures.shared.[feature].isEnabled` runtime check
- [ ] Isolates changes to separate files as much as possible (e.g. via Swift extensions)
