# LiNUZE
A jailbreak app to manage iDevices using jailbroken iDevices.

[![CI](https://img.shields.io/github/actions/workflow/status/rA9stuff/LiNUZE/ci.yml?branch=master&style=for-the-badge)](https://github.com/rA9stuff/LiNUZE/actions)
[![Stars](https://img.shields.io/github/stars/rA9stuff/linuze?style=for-the-badge)](https://github.com/rA9stuff/LiNUZE/stargazers)
[![Licence](https://img.shields.io/github/license/rA9stuff/linuze?style=for-the-badge)](https://github.com/rA9stuff/LiNUZE/blob/master/LICENSE.md)
<br/>
<img align="right" src="https://i.imgur.com/bGJLzqv.png" width="130px" height="130px">
### Downloads
* [Latest public release (Recommended)](https://github.com/rA9stuff/LiNUZE/releases)
* [Latest nightly build (Experimental)](https://nightly.link/rA9stuff/LiNUZE/workflows/ci/master)

### 🤍 Support this project
* [Patreon](https://www.patreon.com/rA9stuff)

# How to use?
* Add https://ra9stuff.github.io/repo to your favorite package manager.
* Browse the repo and download LiNUZE along with it's dependencies.
* Connect another iDevice to your device and start using it.

# Which adapter is needed for devices with Lightning connectors?

Honestly, most "USB 3" lightning to USB-A adapters *should* work just fine. I'll list the two adapters that I used and confirmed to be working with LiNUZE. This is **NOT** a free advertisement for these products. I'm just sharing the experience.

### Apple's lightning to USB camera adapter
Probably the most popular one you'll find. I haven't tried the "USB 3" version of this adapter, but it should work fine.
Common issues I've encountered with this adapter is that sometimes iOS refuses to power the connected device, and you'll get an alert like [this.](https://i.imgur.com/7NmdfMo.jpg) I was able to bypass this by using a USB-A splitter, which probably reduced the power consumption of the connected device. Still, I wouldn't recommend this one if you're looking for a stable experience with LiNUZE. [Product link](https://www.apple.com/shop/product/MD821AM/A/lightning-to-usb-camera-adapter)
### Any other USB 3 certified adapter
Honestly, these are much better than what Apple offers. Browse AliExpress and search for the terms "lightning otg usb 3" and buy one with product reviews in mind. I would recommend keeping it simple and just getting a plain lightning to USB-A adapter, instead of janky HUBs that include HDMIs, SD Card readers, etc.   

This list will be updated as more and more users confirm different adapters to be working.

# How to build?

* Open `LiNUZE.xcodeproj`.   
* Adjust your library and header search paths.   
* Close `Xcode`, `cd` into project directory and run `./compile [iDevice root password which you can leave empty]`.   
* A file named `com.ra9stuff.LiNUZE.deb` will appear in the project directory.   
   
Note that `compile` uploads the compiled `.deb` file to device with the given IP using the iDevice root password in the parameter. Make sure to change adjust them as well if you want your file to be uploaded to your device. You may leave the root password parameter empty, if you just want a `.deb` to be produced.

# Common Issues & Troubleshooting

...none for now?   

# Supporters

* Will Kellner

You can [support the project](https://www.patreon.com/rA9stuff) to get your name displayed here.
