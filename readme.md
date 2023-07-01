Because our family now uses Omnipod 5, I (Jon Fawcett) will not be updating this repository. I will also no longer provide an option to get a TestFlight invitation from me. You must build the app yourself.

The Loop and Learn Team will keep the Loop Follow app going; it will stay at this repository. Additional Loop Follow documentation is at [Loop and Learn: Loop Follow](https://www.loopandlearn.org/loop-follow/).

If you are having problems with the app, please post in the [Loop and Learn Facebook group](https://www.facebook.com/groups/LOOPandLEARN). Your post should indicate that your question is related to Loop Follow. If you do not use Facebook - please click on this [link to file an Issue](https://github.com/jonfawcett/LoopFollow/issues) with your problem.

If you are interested in assisting with this app and want to work on new features and improvements for Loop, iAPS and Nightscout functionality, please reach out. Issues and Pull Requests in GitHub are monitored and will get a response.

## Loop Follow 
![screenshot](https://user-images.githubusercontent.com/38429455/93782187-436e8880-fbf8-11ea-8709-e2afba692132.png)

### Purpose:

Using so many different apps as a parent or caregiver of a T1D can be very cumbersome. Add in the extra details from Looping
and it can be a challenge flipping back and forth between apps. Each app has different strengths and weaknesses.
- Spike is great for alarms. 
- Spike and Sugarmate are great for the calendar complication on Apple Watch. 
- Nightscout X or Nightscout in Safari are needed for intricate details from NS.
- IFTTT and Pushover are  needed for Not Looping alerts.

And there are some functions I've always wished for and not found anywhere such a one-time temporary alert
for those nights when Loop is stuck on high and you open loop with a correction. This lets you set a higher
low alert for the BG you want to wake up to and close Loop.

### Building Options

### GitHub Browser Build

Loop Follow can be built using a paid Apple Developer Account on any computer using the GitHub Browser Build method as explained (tersely) [here](fastlane/testflight.md) or with more detail in [LoopDocs: GitHub Browser Build: Other Apps](https://loopkit.github.io/loopdocs/gh-actions/gh-other-apps).

If you choose GitHub Browser Build and want to run Loop Follow on your Mac, you need to install the TestFlight app on your Mac. The TestFlight app shows the same set of builds and uses the same installation procedure as shown in LoopDocs for installing apps on a phone from TestFlight; just do it on your Mac.

> **Note**
> If you used Jon's TestFlight invitation to download your Loop Follow, that is no longer available. You need to build it yourself. Click on [TestFlight: Two Apps](#testflight-two-apps) for more information. If you never used that invitation, you don't need to read that section.
> ...

### Build using Mac-Xcode

Loop Follow can be built using a Mac computer with Xcode as described below (tersely) or with more detail using the Build-Select script, see [Loop and Learn: Build-Select Script](https://www.loopandlearn.org/build-select) or [LoopDocs: Build Select Script](https://loopkit.github.io/loopdocs/build/step14/#build-select-script) and choose to build Loop Follow.

1. Open Terminal
2. copy/paste this code into terminal and hit enter:
```
/bin/bash -c "$(curl -fsSL \
  https://raw.githubusercontent.com/loopandlearn/lnl-scripts/main/BuildLoopFollow.sh)"
```
3. Follow instructions in terminal
4. This script assists in checking the status of your Xcode version, automatically signing your app and preparing the profiles to provide a full year for this app.
5. At the end of the script, you will be told to plugin your phone or ipad and click play.

Note: This script is tested when new iOS, Mac and Xcode versions are released. Check [Loop and Learn: Version Updates](https://www.loopandlearn.org/version-updates/) for up to date information.

### Run Loop Follow on Mac

To run Loop Follow on your Mac, you need to move the app to your Applications folder.

After building to your Mac (using the script above):
1. Click stop to close the running app
1. On the left side of Xcode, click on the Folder icon
    * Click to open the LoopFollow folder list
    * Click to open the LoopFollow/Products folder
    * Right click (or Cntl-click) on "Loop Follow.app" and select Show in Finder
4. Drag the Loop Follow.app icon to your Applications folder in finder (see Note below)
5. From Mac system settings/notifications, scroll down to Loop Follow and enable notifications with the options you want. For instance, Badge app icon will allow the BG reading to display on the icon.

> **Note**
> If you have a Loop Follow app in your Applications folder from a prior TestFlight installation, then when you drag the Loop (from Finder location) to Applications, you will be asked if you want to Replace or Keep Both. Choose Replace.
> ...

Build Instruction Video: https://youtu.be/s07QPZ7xycY

Special thanks to Spike-App, NSApple, and Nightguard for helping me figure out how to do a lot of the code for this.

If you want to contribute, the biggest needs today are to make the code cleaner and more efficient, and create the basis for a watch app.

### General feature list
- scrollable/scalable graph display with BG, basal, bolus, and carb details plus Loop status, Loop Prediction, and the General NS Care portal info.
- Override DND and system volume for all alerts.
- snoozes per alert, presnooze, edit existing snooze, and snooze all alert settings.
- the standard Low/High, Urgent Low/High, and missed reading alerts. High will have a persistence option that’s still to do. Eg high for x minutes.
- fast drop/rise alerts with BG limits. Eg Trigger fast drop only when under a BG where it’s an issue.
- sage/cage reminder alerts for x hours before change.
- Not Looping with Bg limits alert. So you can trigger the alert only if under or over a BG range.
- Missed Bolus alert.
- calendar entries to use watch complication with BG, arrow, delta, cob, iob and minutes ago (if old reading).
- background silent audio to keep iOS from killing the app. This is why it can’t go in the App Store for just a simple download.

### Contributing, Building, and Branches
- New code will be pushed to the Dev branch as soon as it has been added. It might be very rough around the edges. Once it has been thoroughly tested, it will be merged to Master. If you are even remotely adventurous, please build Dev to help test the new features as they are added.
- If you want to contribute, please PR on Dev unless it is an important bug fix to address in Master

### Open Source DIY
- This is a DIY open source project that may or may not function as you expect. You take full responsibility for building and running this app and do so at your own risk.

### TestFlight: Two Apps

If you have a Loop Follow app in your Applications folder from a prior Mac/Xcode build and then install from TestFlight:

* TestFlight does not ask if you want to replace your app - you get a second app, Loop Follow 2.app, in your Applications folder
* You can then delete the original Loop Follow.app and rename the TestFlight version from Loop Follow 2.app to Loop Follow.app
* Subsequent installations from TestFlight overwrite the app
* Your settings are maintained regardless of the app name
