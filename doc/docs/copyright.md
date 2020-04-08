# Copyright / License

Now that Faust libraries are less author specific, each function will normally have its own copyright-and-license line in the library source (the `.lib` file, such as `analyzers.lib`). If not, see if the function is defined within a section of the `.lib` file stating the license in source-code comments.  If not, then the copyright and license given at the beginning of the `.lib` file may be assumed, when present.  If not, run `git blame` on the `.lib` file and ask the person who last edited the function!

Note that it is presently possible for a library function released under one license to utilize another library function having some different license.  There is presently no indication of this situation in the Faust compiler output, but such notice is planned.  For now, library contributors should strive to use only library functions having compatible licenses, and concerned end-users must manually determine the union of licenses applicable to the library functions they are using.

## STK 4.3 License

The Synthesis ToolKit in C++ (STK) is a set of open source audio signal processing and algorithmic synthesis classes written in the C++ programming language. STK was designed to facilitate rapid development of music synthesis and audio processing software, with an emphasis on cross-platform functionality, realtime control, ease of use, and educational example code.  STK currently runs with realtime support (audio and MIDI) on Linux, Macintosh OS X, and Windows computer platforms. Generic, non-realtime support has been tested under NeXTStep, Sun, and other platforms and should work with any standard C++ compiler.

STK WWW site: <http://ccrma.stanford.edu/software/stk/>

The Synthesis ToolKit in C++ (STK) Copyright (c) 1995--2017 Perry R. Cook and Gary P. Scavone

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

Any person wishing to distribute modifications to the Software is asked to send the modifications to the original developer so that they can be incorporated into the canonical version.  For software copyrighted by Julius O. Smith III, email your modifications to <jos@ccrma.stanford.edu>.  This is, however, not a binding provision of this license.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## LGPL License

This program is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along with the GNU C Library; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.
