# The Pleasuredemo (1990-2024)
Source code for [The Pleasuredemo](https://demozoo.org/productions/362493/), an Atari ST demo collection from The Cyberpunks (UK)

**Please note: the music has been removed from all screens because I want to release the demo under a permissive license and the music was all ripped.**

The Ultramega Scroller has been adapted to run without the sample file, but it can be extracted from the disk image at [DemoZoo](https://demozoo.org/productions/362493/) if you want to have the audio.

*If you want to add music back in to the screens you can download equivalent rips from [The SNDH Archive](https://sndh.atari.org/). This will require uncommenting some code in each screen and adapting it to work with the SNDH format rather than the custom .MSX format which we used for our rips (basically a matter of replacing +4 with +8 in the VBL jump address). I will probably update the screens to work with the SNDH format by default, so that dropping in an SNDH file is all that is needed to get music.*

Work on this demo began in 1990, but came to a halt when Zax's ST overheated and died. It was resumed in 1991.

Screens were written and rewritten until in November 1991 the demo was ready for release - pending permission to use the sample on The Ultramega Scroller.

We continued to tinker with some of the screens while we waited, until a year later we finally got a reply. They said "no".

We had ideas for replacing the sample, but by this time we had kind of moved on and never got around to it, so The Pleasuredemo remained unreleased.

In 2024 I (Zax) was clearing out things from my mother's attic and came across a bag of floppy disks, including The Pleasuredemo and various dev disks. 

I sent them to Tronic of Effect, who was able to read and recover the data, and sent me photos of The Pleasuredemo running on an ST.

Unfortunately, the 1992 version does not run under emulation (both Hatari and Steem bomb on the bootstrap).

I started working on a new bootstrap to see if I could get it running, which meant dusting off long unused 68000 assembly knowledge.

Eventually I decided it would be better to put together a new version, removing some older screens that didn't hold up as well.

This involved reverse engineering the code to understand it (apparently we were not big on comments or meaningul names!),
and fixing all the screens to build with VASM and to run either from the new boostrap or as standalone executables.

Three screens were removed (they may be released separately) and one was added (3D Format aka Small Balls was originally a standalone demo).

Some scrolling messages were edited for brevity, and to remove some of the more embarrasing things I wrote as a teenager!

Here are the details for each screen, as best as I can remember them.

## INTRO
Originally written in 1991 I think, though the tracking sprites may have been added in 1992.

Received a bit of polish in 2024:
- triple buffered to improve the sense of movement on modern displays
- rearranged some codes to open an extra 6 lines at the bottom
- replaced sample with a better quality loop from Welcome To The Pleasuredome

## MAIN MENU
I think this was written in late 1991 to replace the original menu, which dated back to early 1990 and looked like it.

2024: updated with the new screen lineup and to work with the new boostrap.

## THE ULTRAMEGA SCROLLER
Written in 1991, based on an older screen, updated in 1992 with cleaner sample playback.

2024: digitally resampled the music and resequenced with cleaner loop points. Rearranging some code added 4 more lines to the scroller, which also improves the sound quality since the display and audio are interleaved.

## CLASS IN A GLASS
The message in the earliest version says it was the first screen I wrote after getting my new ST, so early 1991 I think. It was updated with faster sprite routines (more balls) and the colour distorter later in 1991 (possibly 1992).

2024: replaced the music with relocatable rip from SNDH, added selectable palettes for the distorter, improved the sync routine to get rid of a black line that had bothered me for over 33 years.

## THE SUMMER DEMO
Written in one weekend in summer 1990, one evening in summer 1991 and one weekend in summer 1992 (according to the scroller).

## THE LOVE DEMO
Written in July 1991.

2024: replaced the Chimera music with the SNDH rip and removed some other music to reduce the file size. Fixed a bug that caused a crash with the new bootstrap.

## REFLEXIONS
Written in April 1991, according to the message!

## THE HELIX DEMO
Written some time in 1991.

## SOUL PSYCHEDELICIDE
Started life as a standalone demo written in 1989, but almost completely rewritten in 1991 for The Pleasuredemo.

2024: Replaced Zoolook music with relocatable SNDH rip, removed some music to reduce file size.

## THE REPTILE HOUSE
Another standalone screen from 1989 or 1990 that received some polish in 1991.

2024: Changed the default pattern for the palette scroller.

## SMALL BALLS
Not originally part of The Pleasuredemo, this was a standalone screen that was intended for ST Format. As far as I can remember we never actually submitted it. 

According to the original readme:

*Coded in 1993 by Zax and Vilm*
*Time travel facilities by generous donation of The Cyberpunk Corporation.*

Unfortunately the time travel appears to have been in the opposite direction to what was (presumably) intended.

2024: Added the Atari logo, some minor optimisations and changed keyboard shortcuts for PC convenience. 
