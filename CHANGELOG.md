# Changelog

## Build 40
### Fixed
- SSH not working
- Paste button being the wrong color in dark mode
- gem install eventmachine failing due to missing system calls

## Build 39
### New
- irssi
- rubygems
- fish
- traceroute (thanks @wallisch)
- mtr
- rcl and rcr are implemented, leaving gcc with no more known reasons to crash
- Enough of /proc for ps and killall to work
- epoll (you can now install python packages with dependencies!)
- Paste button (with bad icon, oh well)
### Fixed
- phpinfo() crashing the app
- tar hanging after finishing extraction
- Rare crash when starting a process due to RNG failure

## Build 37
### Fixed
- Keyboard buttons being the wrong color in dark theme

## Build 36
### New
- Emacs
- /dev/random and /dev/urandom (thanks @lunixbochs)
- Perl
- dialog
- ping (thanks @wallisch)
- Auto lock control setting
### Fixed
- I accidentally installed shadow and coreutils and everything broke. Instead of reinstalling and losing my filesystem I fixed everything.
- Arrow keys being invisible to VoiceOver, as well as a couple other VoiceOver tweaks
- Better hide keyboard button
- Stepper for font size selection
- resolv.conf not getting truncated when overwritten
- SIGWINCH with no handler installed interrupting blocking syscalls
- GCJ crashing the app (it still fails for many other reasons, oh well)

## Build 35
### New
- Server sockets
- SSH client works (apk add openssh-client)
### Fixed
- `out of memory`/`short read` error from tar, due to fork setting brk to 0
- Signals not being blocked while the signal handler is running
- Orphaned processes not being reparented to init
- Git doing strange things when it gets a signal
- /dev/tty not existing (if you're not installing from scratch, you have to run mknod /dev/tty c 5 0 to get it)
- Copy button on iOS not existing
- Segfault when trying to run a binary that requires glibc
- irb exiting with an EINVAL due to stdin not reporting that it is open in read/write mode
- ffmpeg reporting "Unknown encoder: 'copy'" on iOS due to 8-bit string compares not working

## Build 34
### New
- Enough stubs and instructions to get numpy to import successfully.
- DARK MODE
### Fixed
- Massive VM leak, if you allocated 100M with mmap only the first 16k would ever get freed. This fixes MemoryError when installing stuff with pip.
- Terminal is now correctly sized instead of overlapping with the keyboard initially.
- You can now select text without making the keyboard go away.

## Build 33
### New
- Database changed from GDBM to SQLite, it's now much more reliable. You will need to reinstall the app, otherwise you'll get an error on launch.
### Fixed
- Segfault while doing large download with pip, due to returning NULL from successful mremap. ffmpeg also had this problem.
- File provider now shows files like it's supposed to.