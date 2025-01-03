The Pleasuredemo (1990-2024)
Written by Simon Booth and Simon Brown
aka Zax and Vilm of The Cyberpunks

Work on this demo began in 1990, but came to a halt when 
Zax's ST overheated and died and wasn't resumed until 1991.

Screens were written and rewritten until in November 1991 
the demo was ready for release - pending permission to use 
a sample from U2's The Fly on The Ultramega Scroller.

We continued to tinker with some of the screens while we waited, 
until a year later we finally got a reply. They said "no".

We had ideas for replacing the sample, but by this time we had
kind of moved on and never got around to it, 
so The Pleasuredemo remained unreleased.

In 2024 I (Zax) was clearing out things from my mother's attic 
and came across a bag of floppy disks, including The Pleasuredemo
and various dev disks. 

I sent them to Tronic of Effect, who was able to read and recover
the data, and sent me photos of The Pleasuredemo running on an ST.

Unfortunately, the 1992 version does not run under emulation
(both Hatari and Steem bomb on the bootstrap).

I started working on a new bootstrap to see if I could get it running,
which meant dusting off long unused 68000 assembly knowledge.

Eventually I decided it would be better to assemble a new version,
removing some older screens that didn't hold up as well.

This involved reverse engineering the code to understand it
(apparently we were not big on comments or meaningul names!),
and fixing all the screens to build with VASM and to run either
from the new boostrap or as standalone executables.

Three screens were removed (they may be released separately) and 
one was added (Small Balls was originally a standalone demo).

Some scrolling messages were edited for brevity,
and to remove some of the more embarrasing things I wrote as a teen!

Finally, after 2 months and 34 years, 
The Pleasuredemo (2024) is ready for release... 
and no Irish rock band is going to stop it this time!

Here are the details for each screen, as best as I can remember them.

INTRO
Originally written in 1991 I think,
though the tracking sprites may have been added in 1992.

Received a bit of polish in 2024:
- triple buffered to improve the sense of movement on modern displays
- rearranged some codes to open an extra 6 lines at the bottom
- replaced sample with a better quality loop from Welcome To The Pleasuredome

MAIN MENU
I think this was written in 1992 to replace the original menu, 
which dated back to early 1990 and looked like it, but it may have been 1991.

2024: updated with the new screen lineup and to work with the new boostrap.

THE ULTRAMEGA SCROLLER
Written in 1991, based on an older screen,
updated in 1992 with new colours and cleaner sample playback.

2024: digitally resampled the music and resequenced 
with cleaner loop points. Rearranging some code added 
4 more lines to the scroller.

CLASS IN A GLASS
The message in the earliest version says it was the first screen 
I wrote after getting my new ST, so early 1991 I think. It was 
updated with faster sprite routines (more balls) and the colour
distorter later in 1991 (possibly 1992).

2024: replaced the music with relocatable rip from SNDH,
added selectable palettes for the distorter, improved the sync routine 
to get rid of a black line that had bothered me for over 33 years.

THE SUMMER DEMO
Written in one weekend in summer 1990, one evening 
in summer 1991 and one weekend in summer 1992 
(according to the scroller).

THE LOVE DEMO
Written in July 1991.

2024: replaced the Chimera music with the SNDH rip and 
removed some other music to reduce the file size.
Fixed a bug that caused a crash with the new bootstrap.

REFLEXIONS
Written in April 1991, according to the message!

THE HELIX DEMO
Written some time in 1991.

SOUL PSYCHEDELICIDE
Started life as a standalone demo written in 1989,
but almost completely rewritten in 1991 for The Pleasuredemo.

2024: Replaced Zoolook music with relocatable SNDH rip, 
removed some music to reduce file size.

THE REPTILE HOUSE
Another standalone screen from 1989 or 1990 
that received some polish in 1991.
2024: Changed the default pattern for the palette scroller.

SMALL BALLS
Not originally part of The Pleasuredemo, 
this was a standalone screen that was intended for ST Format.
As far as I can remember we never actually submitted it. 

According to the original readme:

Coded in 1993 by Zax and Vilm
Time travel facilities by generous donation of The Cyberpunk Corporation.

2024: Added the Atari logo, some minor optimisations
and changed keyboard shortcuts for PC convenience. 
