ofxAddonTool CHANGELOG
======================
### Version 0.5 (master)
- Fix: Local branch changes were using the remote tracking branch instead of the local branch name, trowing errors then they were different.

### Version 0.4_alpha (05-12-2020):
- Fix: Fixed how the project folder is detected : it now looks for addons.txt in the root of your project
- Fix: The script now also looks for your addons folder in `../../`, allowing the script to run from within the oF addons folder too
- Clarified the setup in the readme
- Typos

### Version 0.3_alpha (10-10-2020):
- Fix: Table layout on Windows
- Fix: Banner takes full width
- Improves the detection of errors
- Fixes for main project repo showing incorrect git information in some configurations
- Implements the option to install uninstalled addons
- Feature: Shows working information while execting
- Implements the option to update addons
- Removed some unused variables
- Implements the option to sync addons.txt --> addons.make
- Added screenshot to the readme

### Version 0.2_alpha (28-09-2020):
- Improves display layout
- Added help
- Supports arguments
- Create git repository with instructions

### Version 0.1_alpha (20-09-2020):
- [Initial release](https://github.com/d3cod3/Mosaic/commit/da0737283725eed5f7431ef09f024f8fe27a3158), allowing to check the addons folder.

