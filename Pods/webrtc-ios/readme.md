WebRTC iOS Static libs
--------------------------

The process involved in building WebRTC from source is very complicated, and iOS support in the main repo is of highly variable quality. This is a set of precompiled libraries packaged as a Cocoapod to allow easily building WebRTC based apps on iOS/

**webrtc-base.patch**

This is a patch file to apply to the main webrtc distribution to get functional ios libraries. Previosly this contained portions of the actual video support, but that has since been mainlined, now it just contains some fixes to make it build properly with newer SDK releases. 

If you need to build the main WebRTC libs yourself, the best instructions I've found on how to do that are here: http://ninjanetic.com/how-to-get-started-with-webrtc-and-ios-without-wasting-10-hours-of-your-life/. Now that video support has been mainlined, the particular version needed to build should not be as important as it was previously, however there may still be incompatibilities in particular version. 

The current version that we use is 5858. So you may want to make sure that the source is at the correct revision, so rather than just running 
    gclient sync
to sync the depot, run
    gclient sync trunk@5858

**libvpx.patch**

Some patches to work around some iOS specific problems with libvpx that can cause crashes or decode corruption in release mode. See:

https://code.google.com/p/webm/issues/detail?id=603 and https://code.google.com/p/webrtc/issues/detail?id=3038 for details.

Needs to be applied seperatly in third_party/libvpx due to nested svn repositories.

**lib**

These are compiled copies of the libs build from the main source with the above patches applied.

Note that the libraries are release mode, armv7 only. The WebRTC build pipeline seems incapable of producing armv7s or arm64 binaries at this time. 

**include**

This is a copy of the header files for the ObjectiveC interface to WebRTC, from 'talk/app/webrtc/objc' in the WebRTC distribution.
