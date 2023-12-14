> **Message from the Loop and Learn Team:**
> * We have taken responsibility for updates to the Loop Follow app
> * Additional Loop Follow documentation is at [Loop and Learn: Loop Follow](https://www.loopandlearn.org/loop-follow/)
> * If you are having problems with the app:
>     * Post in the [Loop and Learn Facebook group](https://www.facebook.com/groups/LOOPandLEARN); indicate that your question is related to Loop Follow
>     * If you do not use Facebook - please click on this [link to file an Issue](https://github.com/loopandlearn/LoopFollow/issues) with your problem

> **New location for LoopFollow Repository:**
> * If you previously created a fork of LoopFollow from the JonFawcett username
>    * Please note the repository name has changed to [https://github.com/loopandlearn/LoopFollow](https://github.com/loopandlearn/LoopFollow)
>    * GitHub should automatically redirect you to this new address
>    * We have also modifed one branch and one file name to match standard conventions: _main_ (from _Main_) and _README.md_ (from _readme.md_)

> **Message from Jon Fawcett:**
> * Because our family now uses Omnipod 5, I will no longer be involved in updating LoopFollow
> * I have transferred the _LoopFollow_ repository from the _JonFawcett_ to the _loopandlearn_ username
> * I will also no longer provide an option for a TestFlight invitation from me. (Jon Fawcett)
>   * You must build the app yourself.

> **Message to Developers**

* Please click on this link: [For Developers](#for-developers)

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

Please see [Loop and Learn: Loop Follow](https://www.loopandlearn.org/loop-follow/) for all the building options.

With the release of version 2.1.0, there is now an easy option for building up to three instances of the Loop Follow app for multiple Loopers in your family. Each instance can be configured to have the display name you choose with these names being the default:

* LoopFollow
* LoopFollow_Second
* LoopFollow_Third

#### Display Name Updates

The _display_name_ is found in a single file.

* Suggestion if you customize the name: use LF {unique name} so you can find the apps easily in iOS Settings screen

Summary instructions by build method:

* Browser Build: 
    * Fork and setup the repository for each Loop Follow instance you want to use: 
        * https://github.com/loopandlearn/LoopFollow
        * https://github.com/loopandlearn/LoopFollow_Second
        * https://github.com/loopandlearn/LoopFollow_Third
    * Commit the desired _display_name_ in the LoopFollowDisplayNameConfig.xcconfig file of your forked repository for LoopFollow, LoopFollow_Second or LoopFollow_Third
* Mac-Xcode Build
    * First build with script, you will be prompted to enter the desired _display_name_
    * This _display_name_ is used each time you select a fresh download for LoopFollow 1, 2 or 3
    * To modify the _display_name_ for subsequent script builds, edit the appropriate file in the ~/Downloads/BuildLoopFollow folder
        *  LoopFollowDisplayNameConfig.xcconfig 
        *  LoopFollowDisplayNameConfig_Second.xcconfig 
        *  LoopFollowDisplayNameConfig_Third.xcconfig 

#### Updates

When modifications and versions are updated, there might be a slight delay for getting the second and third forks updated as well, so if you are using this feature, wait until all three repositories are updated.

### General feature list

Please review the list on [Loop and Learn: Loop Follow](https://www.loopandlearn.org/loop-follow/) which may be updated more frequently than this README.md file.

- scrollable/scalable graph display with BG, basal, bolus, and carb details plus Loop status, Loop Prediction, and the General NS Care portal info.
- Override DND and system volume for all alerts.
- snoozes per alert, presnooze, edit existing snooze, and snooze all alert settings.
- the standard Low/High, Urgent Low/High, and missed reading alerts with additonal option to select persistence; for example, alert when high for x minutes.
- fast drop/rise alerts with BG limits; for example, alert for fast drop only when glucose is below specific value.
- sage/cage reminder alerts for x hours before change.
- Not Looping with glucose limits alert: you can configure the alert if under or over a glucose range.
- Missed Bolus alert.
- calendar entries to use watch complication with BG, arrow, delta, cob, iob and minutes ago (if old reading).
- background silent audio to keep iOS from killing the app. This is why it can’t go in the App Store for just a simple download.

### Open Source DIY
- This is a DIY open source project that may or may not function as you expect. You take full responsibility for building and running this app and do so at your own risk.

## For Developers

> * If you are interested in assisting with this app and want to work on new features and improvements for Loop, iAPS and Nightscout functionality, please reach out. 
> * Issues and Pull Requests in GitHub are monitored and will get a response. 
> * Please always direct your PR to the dev branch.

### Versions

We added version numbers that are incremented with each pull request (or group of pull requests) merged.

New PR are directed to the dev branch. If you direct one to main, we will move it to point to dev. So always start with your code aligned with dev.

The versioning is:

* major.minor.micro
* For example our first version is 2.0.0

After a PR is merged to dev, the repository maintainers will bump up the verion number before merging to main - please do not modify the version in your branch.

For the most part, the deveopers keep main and dev branches at the same level. But sometimes we want modification to remain in dev for additional testing.

#### Version Example

Starting with version 2.1.0

* PR with Feature A gets merged to dev
    * Maintainers, bump dev to 2.1.0
* Maintainers merge dev into main
    * both main and dev are at 2.1.0
* PR with Feature B gets merged to dev
    * Maintainers, bump dev to 2.1.1
    * main is still at 2.1.0
* PR with Feature C gets merged to dev
    * Maintainers, bump dev to 2.1.2
    * main is still at 2.1.0
* Maintainers merge dev into main
    * both main and dev are at 2.1.2

#### Version Updates

Modify the LOOP_FOLLOW_MARKETING_VERSION in Config.xcconfig file to change the version reported by Loop Follow.
