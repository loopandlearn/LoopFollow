Call for developers: Because we have switched to Omnipod 5, we no longer are using Loop or Nightscout. I will not be able to do maintenance on the features related to those. If you are interested in assisting to keep this app maintained and work on new features and improvements for Loop and Nightscout functionality, please reach out.

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

### App Store Beta Test Install
If you would like to be part of our beta testing for the App Store and install that version without needing to build it yourself, please submit the form here: https://customtypeone.com/blogs/news/loop-follow-beta-testing


### To begin building: 

1. Open Terminal
2. copy/paste this code into terminal and hit enter: `/bin/bash -c "$(curl -fsSL https://git.io/JTKEt)"`
3. Follow instructions in terminal
4. Plugin your phone or ipad, select your signing team, select your phone or ipad or "my mac" (Big Sur only), and click play.

If you build to MacOS Big Sur, after building you need to copy the app to your applications folder:
1. Click stop to close the running app
2. Right click on "Loop Follow.app" in the left side of xcode by clicking to the Loop Follow/Products/ folder
3. Select Show in Finder
4. Drag the Loop Follow.app icon to your Applications folder in finder.
5. From Mac system settings/notifications, scroll down to Loop Follow and enable notifications with the options you want. For instance, Badge app icon will allow the BG reading to display on the icon.

** Big Sur **
Some things do not work correctly yet in Big Sur
- Background Refresh. Mac apps stay open when minimized, so this is unneeded. Please disable the toggle switch.
- Disable Keep Screen Active. I haven't tested, but doubt this will do anything.
- Watch/Carplay calendar selection does not work
- Alarms will not override the Mac volume or mute.

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
