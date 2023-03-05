# Using Github Actions + FastLane to deploy to TestFlight: the "Browser Build" method

These instructions allow you to build Loop Follow without having access to a Mac. They also allow you to easily install Loop Follow on phones that are not connected to your computer. So you can send builds and updates to those you care for easily, or have an easy to access backup if you run Loop Follow for yourself. You do not need to worry about correct Xcode/Mac versions either. An app built using this method can easily be deployed to newer versions of iOS, as soon as they are available.

The setup steps are somewhat involved, but nearly all are one time steps. Subsequent builds are trivial. Your app must be updated once every 90 days, but it's a simple click to make a new build and can be done from anywhere.

Note that TestFlight requires apple id accounts 13 years or older. This can be circumvented by logging into Media & Purchase on the child's phone with an adult's account. More details on this can be found in [LoopDocs](https://loopkit.github.io/loopdocs/gh-actions/gh-deploy/#install-testflight-loop-for-child).

This method for building without a Mac was ported from Loop. If you have used this method for Loop or one of the other DIY apps (Loop Caregiver, Loop Follow, Xdrip4iOS, FreeAPS X), some of the steps can be re-used and the full set of instructions does not need to be repeated. This will be mentioned in relevant sections below.

There are more detailed instructions in LoopDocs for doing Browser Builds of Loop and other apps, including troubleshooting and build errors. Please refer to [LoopDocs](https://loopkit.github.io/loopdocs/gh-actions/gh-other-apps/) for more details.

## Prerequisites

* A [github account](https://github.com/signup). The free level comes with plenty of storage and free compute time to build Loop Follow, multiple times a day, if you wanted to.
* A paid [Apple Developer account](https://developer.apple.com).
* Some time. Set aside a couple of hours to perform the setup.
* Use the same GitHub account for all "Browser Builds" of the various DIY apps.
* You require 6 Secrets (alphanumeric items)  - make sure you save them; and do not use a smart editor because these Secrets are case sensitive.

## Generate App Store Connect API Key

This step is common for all "Browser Builds", and should be done only once. Please save the API key with your Secrets.

1. Sign in to the [Apple developer portal page](https://developer.apple.com/account/resources/certificates/list).
1. Copy the team id from the upper right of the screen. Record this as your `TEAMID`.
1. Go to the [App Store Connect](https://appstoreconnect.apple.com/access/api) interface, click the "Keys" tab, and create a new key with "Admin" access. Give it the name "FastLane API Key".
1. Record the key id; this will be used for `FASTLANE_KEY_ID`.
1. Record the issuer id; this will be used for `FASTLANE_ISSUER_ID`.
1. Download the API key itself, and open it in a text editor. The contents of this file will be used for `FASTLANE_KEY`. Copy the full text, including the "-----BEGIN PRIVATE KEY-----" and "-----END PRIVATE KEY-----" lines.

## Setup Github Match-Secrets repository

The creation of the Match-Secrets repository is also a common step for all "browser builds", do this step only once.
1. Create a [new empty repository](https://github.com/new) titled `Match-Secrets`. It should be private.

## Setup Github LoopFollow repository

1. Fork https://github.com/jonfawcett/LoopFollow into your account. If you already have a fork of LoopFollow in GitHub, you can't make another one. You can continue to work with your existing fork, or delete your existing fork from GitHub and then create a new fork from https://github.com/jonfawcett/LoopFollow.

NOTE: if your default branch is not set to the Main branch for LoopFollow, you will NOT see the expected build actions. Follow these steps in [LoopDocs](https://loopkit.github.io/loopdocs/gh-actions/gh-update/#set-default-branch) to select Main as your default branch.

The first time you build with the GitHub Browser Build method for any DIY app, you will generate a personal access token and make up a password (MATCH_PASSWORD) for the Match-Secrets repository. If you lose your MATCH_PASSWORD, you will need to delete the Match-Secrets repository, create a new one and make up a new password (used for all repositories for which you use the GitHub build method).

If you have previously built Loop or another app using the GitHub "browser build" method, you should re-use your previous personal access token (`GH_PAT`) and MATCH_PASSWORD and skip ahead to `step 2`.
1. Create a [new personal access token](https://github.com/settings/tokens/new):
    * Enter a name for your token, use "FastLane Access Token".
    * Select 90 days for this token.
    * Select the `repo` permission scope.
    * Click "Generate token".
    * Copy the token and record it. It will be used below as `GH_PAT`.
1. In the forked LoopFollow repository, go to Settings -> Secrets -> Actions.
1. For each of the following secrets, tap on "New repository secret", then add the name of the secret, along with the value you recorded for it:
    * `TEAMID`
    * `FASTLANE_KEY_ID`
    * `FASTLANE_ISSUER_ID`
    * `FASTLANE_KEY`
    * `GH_PAT`
    * `MATCH_PASSWORD`

## Validate repository secrets

This step validates most of your six secrets and provides error messages if it detects an issue with one or more.

1. Click on the "Actions" tab of your LoopFollow repository.
1. Select "1. Validate Secrets".
1. Click "Run Workflow", and tap the green button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.
1. The workflow will check if the required secrets are added and that they are correctly formatted. If errors are detected, please check the run log for details.

## Add Identifiers for Loop Follow App

1. Click on the "Actions" tab of your LoopFollow repository.
1. Select "2. Add Identifiers".
1. Click "Run Workflow", and tap the green button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.


## Create Loop Follow App in App Store Connect

If you have created a Loop Follow app in App Store Connect before, you can skip this section as well.

1. Go to the [apps list](https://appstoreconnect.apple.com/apps) on App Store Connect and click the blue "plus" icon to create a New App.
    * Select "iOS".
    * Select a name: this will have to be unique, so you may have to try a few different names here, but it will not be the name you see on your phone, so it's not that important.
    * Select your primary language.
    * Choose the bundle ID that matches `com.TEAMID.LoopFollow`, with TEAMID matching your team id.
    * SKU can be anything; e.g. "123".
    * Select "Full Access".
1. Click Create

You do not need to fill out the next form. That is for submitting to the app store.

## Create Building Certficates

1. Go back to the "Actions" tab of your LoopFollow repository in github.
1. Select "3. Create Certificates".
1. Click "Run Workflow", and tap the green button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.

## Build Loop Follow

1. Click on the "Actions" tab of your LoopFollow repository.
1. Select "4. Build Loop Follow".
1. Click "Run Workflow", select your branch, and tap the green button.
1. You have some time now. Go enjoy a coffee. The build should take about 15 minutes.
1. Your app should eventually appear on [App Store Connect](https://appstoreconnect.apple.com/apps).
1. For each phone/person you would like to support Loop Follow on:
    * Add them in [Users and Access](https://appstoreconnect.apple.com/access/users) on App Store Connect.
    * Add them to your TestFlight Internal Testing group.
