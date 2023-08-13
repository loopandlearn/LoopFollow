> **Message from the Loop and Learn Team:**
> * We will keep the Loop Follow app going:
>    * Please note the repository name has changed to [https://github.com/loopandlearn.LoopFollow](https://github.com/loopandlearn.LoopFollow)
>    * GitHub should automatically redirect you
> * Additional Loop Follow documentation is at [Loop and Learn: Loop Follow](https://www.loopandlearn.org/loop-follow/).
> * If you are having problems with the app:
>     * Post in the [Loop and Learn Facebook group](https://www.facebook.com/groups/LOOPandLEARN); indicate that your question is related to Loop Follow. 
>     * If you do not use Facebook - please click on this [link to file an Issue](https://github.com/jonfawcett/LoopFollow/issues) with your problem.

> **Message from Jon Fawcett:**
> * Because our family now uses Omnipod 5, I will no longer involved in updating LoopFollow
> * I have transferred the LoopFollow repository from the JonFawcett to the loopandlearn username
> * I will also no longer provide an option for a TestFlight invitation from me. (Jon Fawcett)
> * You must build the app yourself.

> **Message to Developers**
> * If you are interested in assisting with this app and want to work on new features and improvements for Loop, iAPS and Nightscout functionality, please reach out. 
> * Issues and Pull Requests in GitHub are monitored and will get a response. 
> * Please always direct your PR to the dev branch.

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

### Open Source DIY
- This is a DIY open source project that may or may not function as you expect. You take full responsibility for building and running this app and do so at your own risk.

