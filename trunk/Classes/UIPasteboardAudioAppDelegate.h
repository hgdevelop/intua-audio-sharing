// --------------------------------------------------------------------------------
// UIPasteboardAudio - (c) INTUA s.a.r.l., 2010
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// --------------------------------------------------------------------------------

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioFile.h>

// 5MB max per item in iPhone OS clipboard
#define BM_CLIPBOARD_CHUNK_SIZE (5 * 1024 * 1024)

@interface UIPasteboardAudioAppDelegate : NSObject <UIApplicationDelegate> {
	UIWindow *window;
	UIButton *copyButton;
	UIButton *pasteButton;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UIButton *copyButton;
@property (nonatomic, retain) IBOutlet UIButton *pasteButton;

- (void) showAlert: (NSString *) message;
- (IBAction) doCopyButton;
- (IBAction) doPasteButton;
- (AudioFileID) openAudioFile: (NSString *) path withWriteAccess: (BOOL) writeAcces;
- (void) closeAudioFile: (AudioFileID) audioFileID;
- (void) displayAudioInfo: (AudioFileID) audioFileID;

@end

