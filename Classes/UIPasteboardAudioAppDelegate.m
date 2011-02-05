// --------------------------------------------------------------------------------------------------------------------------------
// UIPasteboardAudio
// Copyright (c) 2010 INTUA s.à.r.l.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without
// limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
// THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// --------------------------------------------------------------------------------------------------------------------------------

#import "UIPasteboardAudioAppDelegate.h"
#import <UIKit/UIPasteboard.h>
#import <MobileCoreServices/UTCoreTypes.h>

// C-fonction for appending metadata information to a string
static void AddInfoToString(const void *_key, const void *_value, void *_context) {
	NSMutableString* fmt = (NSMutableString *) _context;
	NSString* key = (NSString *) _key;
	NSString* val = (NSString *) _value;
	
	[fmt appendFormat:@"\n%@: %@", key, val];
}

@implementation UIPasteboardAudioAppDelegate

@synthesize window;
@synthesize copyButton;
@synthesize pasteButton;

- (void)applicationDidFinishLaunching:(UIApplication *)application {    
	
	// Override point for customization after application launch
	[window makeKeyAndVisible];
}

- (void)dealloc {
	[window release];
	[super dealloc];
}

//! Show a small alert with a message
- (void) showAlert: (NSString *) message {
	UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"UIPasteboardAudio" message:message 
																									delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
  [alert release];
}

#pragma mark -
#pragma mark Copying to clipboard

//! Tag and copy audio data ('sample.wav' inside the resources) to clipboard
- (IBAction) doCopyButton {
	NSString *tmpPath = NSTemporaryDirectory();
	UIPasteboard *board = [UIPasteboard generalPasteboard];
	NSString *srcPath = [[NSBundle mainBundle] pathForResource:@"sample" ofType:@"wav"];
	NSString *dstPath = [NSString stringWithFormat:@"%@sample.wav", tmpPath];

	// Copy file to temp directory (in case we need write access to the file)
	[[NSFileManager defaultManager] copyItemAtPath:srcPath toPath:dstPath error:NULL];
	
	// Open file as binary data
	NSData *dataFile = [NSData dataWithContentsOfMappedFile:dstPath];
	if (!dataFile) {
		[self showAlert:@"doCopyButton: Can't open file"];
		return;
	}
	
	// Create chunked data and append to clipboard
	NSUInteger sz = [dataFile length];
	NSUInteger chunkNumbers = (sz / BM_CLIPBOARD_CHUNK_SIZE) + 1;
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:chunkNumbers];
	NSRange curRange;
	
	for (NSUInteger i = 0; i < chunkNumbers; i++) {
		curRange.location = i * BM_CLIPBOARD_CHUNK_SIZE;
		curRange.length = MIN(BM_CLIPBOARD_CHUNK_SIZE, sz - curRange.location);
		NSData *subData = [dataFile subdataWithRange:curRange];
		NSDictionary *dict = [NSDictionary dictionaryWithObject:subData forKey:(NSString *)kUTTypeAudio];
		[items addObject:dict];
	}
	
	board.items = items;
	[self showAlert:@"File copied to pasteboard"];
}

#pragma mark -
#pragma mark Pasting from clipboard

//! Paste audio data from clipboard into a file
- (IBAction) doPasteButton {
	UIPasteboard *board = [UIPasteboard generalPasteboard];
	
	NSArray *typeArray = [NSArray arrayWithObject:(NSString *) kUTTypeAudio];
	NSIndexSet *set = [board itemSetWithPasteboardTypes:typeArray];
	if (!set) {
		[self showAlert:@"doPasteButton: Can't get item set"];
		return;
	}
		
	// Get the subset of kUTTypeAudio elements, and write each chunk to a temporary file
	NSArray *items = [board dataForPasteboardType:(NSString *) kUTTypeAudio inItemSet:set];		
	if (items) {
		UInt32 cnt = [items count];
		if (!cnt) {
			[self showAlert:@"doPasteButton: Nothing to paste"];
			return;
		}
		
		// Create a file and write each chunks to it.
		NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithString:@"temp-pasteboard"]];
		if (![[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil]) {
			[self showAlert:@"doPasteButton: Can't create file"];
		}
		
		NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
		if (!handle) {
			[self showAlert:@"doPasteButton: Can't open file for writing"];
			return;
		}
		
		// Write each chunk to file
		for (UInt32 i = 0; i < cnt; i++) {
			[handle writeData:[items objectAtIndex:i]];
		}
		[handle closeFile];
		
		//! Quick checks for pasted file recognition
		AudioFileID audioFile = [self openAudioFile:path withWriteAccess:FALSE];
		if (audioFile != nil) {
			[self displayAudioInfo: audioFile];
			[self closeAudioFile: audioFile];
		}
	}
}

#pragma mark -
#pragma mark Audio files metadata manipulation 

//! Open an AudioFileID from a file path, display error if any
- (AudioFileID) openAudioFile: (NSString *) path withWriteAccess: (BOOL) writeAccess {
	// Create a NSURL based on a local file
	NSURL *handle = [NSURL fileURLWithPath:path];
	if (handle == nil) {
		[self showAlert:@"openAudioFile: NSURL fileURLWithPath failed"];
		return nil;
	}
	
	// Get a new AudioFileID
	AudioFileID audioFileID;
	SInt8 perms = writeAccess ? kAudioFileReadWritePermission : kAudioFileReadPermission;
	OSStatus err = AudioFileOpenURL((CFURLRef) handle, perms, 0, &audioFileID);
	if (err != noErr) {
		[self showAlert:@"openAudioFile: AudioFileOpenURL failed"];
		return nil;
	}
	
	return audioFileID;
}

//! Close an AudioFileID
- (void) closeAudioFile: (AudioFileID) audioFileID {
	AudioFileClose(audioFileID);
}

//! Display all the basic information available from an AudioFileID
- (void) displayAudioInfo: (AudioFileID) audioFileID {
	// Get file format
	AudioFileTypeID typeID;
	UInt32 size = sizeof (AudioFileTypeID);
	OSStatus err = AudioFileGetProperty(audioFileID, kAudioFilePropertyFileFormat, &size, &typeID);
	if (err != noErr) {
		[self showAlert:@"displayAudioInfo: AudioFileGetProperty failed"];
		return;
	}
	
	// Get ASBD
	AudioStreamBasicDescription ASBD;
	size = sizeof (AudioStreamBasicDescription);
	err = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &size, &ASBD);
	if (err != noErr) {
		[self showAlert:@"displayAudioInfo: AudioFileGetProperty failed"];
		return;
	}
		
	// Format basic information
	NSMutableString* fmt = [[NSMutableString alloc] init];
	switch (typeID) {
		case kAudioFileAIFFType: {
			[fmt appendFormat:@"Type: AIFF\nSampling Rate: %.2f\nChannels: %u", (float) ASBD.mSampleRate, ASBD.mChannelsPerFrame];											 
		} break;
			
		case kAudioFileWAVEType: {
			[fmt appendFormat:@"Type: WAVE\nSampling Rate: %.2f\nChannels: %u", (float) ASBD.mSampleRate, ASBD.mChannelsPerFrame];											 
		} break;
			
		default: {
      [fmt release];
			[self showAlert:@"Not a WAVE of AIFF file"];
			return;
		} break;
	}
  
	// Get Name, BPM, ...
	err = AudioFileGetPropertyInfo(audioFileID, kAudioFilePropertyInfoDictionary, &size, NULL);
	if (err != noErr) {
		[self showAlert:@"displayAudioInfo: AudioFileGetPropertyInfo failed"];
		[fmt release];
		return;
	}
	CFMutableDictionaryRef infoDict = NULL;
	err = AudioFileGetProperty(audioFileID, kAudioFilePropertyInfoDictionary, &size, &infoDict);
	if (err != noErr) {
		[self showAlert:@"displayAudioInfo: AudioFileGetProperty failed"];
		[fmt release];
		return;
	}
	CFDictionaryApplyFunction(infoDict, AddInfoToString, fmt);
	
	// Show info
	[self showAlert: fmt];	
	[fmt release];
	CFRelease(infoDict);
}

@end

