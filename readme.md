## Loop Follow 

Using so many different apps as a parent or caregiver of a T1D can be very cumbersome. Add in the extra details from Looping
and it can be a challenge flipping back and forth between apps. Each app has different strengths and weaknesses.
- Spike is great for alarms. 
- Spike and Sugarmate are great for the calendar complication on Apple Watch. 
- Nightscout X or Nightscout in Safari are needed for intricate details from NS.
- IFTTT and Pushover are  needed for Not Looping alerts.

And there are some functions I've always wished for and not found anywhere such a one-time temporary alert
for those nights when Loop is stuck on high and you open loop with a correction. This lets you set a higher
low alert for the BG you want to wake up to and close Loop.

Build Instruction Video: https://youtu.be/sdF5v2eGGyA

Special thanks to Spike-App, NSApple, and Nightguard for helping me figure out how to do a lot of the code for this.

If you want to contribute, the biggest needs today are to make the code cleaner and more efficient, get some major details like Bolus/Basal graph and mg/DL vs mmol added, and create the basis for a watch app.

### General feature list
- scrollable/scalable graph display with standard Bg details plus Loop status, Loop Prediction, and the General NS Care portal info.
- option to override DND and system volume for all alerts.
- snoozes per alert, presnooze, edit existing snooze, and snooze all alert settings.
- the standard Low/High, Urgent Low/High, and missed reading alerts. High will have a persistence option that’s still to do. Eg high for x minutes.
- fast drop/rise alerts with BG limits. Eg Trigger fast drop only when under a BG where it’s an issue.
- sage/cage reminder alerts for x hours before change.
- Not Looping with Bg limits. So you can trigger the alert only if under or over a BG range.
- calendar entries to use watch complication with BG, arrow, delta, cob, iob and minutes ago (if old reading).
- background silent audio to keep iOS from killing the app. It has a selectable refresh rate that should help reduce battery usage. This is why it can’t go in the App Store for just a simple download.

### New functionality under consideration
- basal, carb, and insulin entries to the graph.
- missed bolus alert.
- watch app.
- mmol support.
- ability to pull from dex share for Bg. So it can automatically switch to dex BG display for those times when NS has delayed readings.
