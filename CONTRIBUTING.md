# Contributing to CareNest

First off, thank you for considering contributing to CareNest! It's people like you that make CareNest such a great tool.

## 1. Where do I go from here?

If you've noticed a bug or have a feature request, make one! It's generally best if you get confirmation of your bug or approval for your feature request this way before starting to code.

## 2. Fork & create a branch

If this is something you think you can fix, then fork CareNest and create a branch with a descriptive name.

A good branch name would be (where issue #325 is the ticket you're working on):

```sh
git checkout -b 325-add-dark-mode
```

## 3. Get the test suite running

Make sure you're using the correct version of Flutter and Node.js. Install the dependencies and run the tests to ensure everything is working correctly on your machine.

## 4. Implement your fix or feature

At this point, you're ready to make your changes! Feel free to ask for help; everyone is a beginner at first.

## 5. View your changes!

Test your changes locally. If it's a frontend change, ensure it works across different device sizes.

## 6. Make a Pull Request

At this point, you should switch back to your master branch and make sure it's up to date with CareNest's master branch:

```sh
git remote add upstream https://github.com/eldhoaby/CareNest-App.git
git checkout master
git pull upstream master
```

Then update your feature branch from your local copy of master, and push it!

```sh
git checkout 325-add-dark-mode
git rebase master
git push --set-upstream origin 325-add-dark-mode
```

Finally, go to GitHub and make a Pull Request.

## 7. Keeping your Pull Request updated

If a maintainer asks you to "rebase" your PR, they're saying that a lot of code has changed, and that you need to update your branch so it's easier to merge.

## 8. Merging a PR (Maintainers only)

A PR can only be merged into master by a maintainer if:
* It is passing CI.
* It has been approved by at least two maintainers.
* It has no requested changes.
* It is up to date with current master.

### Guidelines
- Keep your commits atomic and well-documented.
- Maintain consistent code formatting.
- Include comments and documentation for complex logic.
