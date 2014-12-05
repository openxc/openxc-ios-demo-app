/*
 
     File: EADSessionTransferViewController.m
 Abstract: n/a
  Version: 1.1
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2010 Apple Inc. All Rights Reserved.
 
 
 */

#import "EADSessionTransferViewController.h"
#import "EADSessionController.h"

@implementation EADSessionTransferViewController

@synthesize
    receivedBytesLabel = _receivedBytesLabel,
    stringToSendTextField = _stringToSendTextField,
    textView = _textView;

// send test string to the accessory
- (IBAction)sendString:(id)sender;
{
    if ([_stringToSendTextField isFirstResponder]) {
        [_stringToSendTextField resignFirstResponder];
    }

    const char *buf = [[_stringToSendTextField text] UTF8String];
    if (buf)
    {
        uint32_t len = strlen(buf) + 1;
        [[EADSessionController sharedController] writeData:[NSData dataWithBytes:buf length:len]];
    }
}


- (IBAction)sendVersionCommand:(id)sender;
{
    const char *buf = "{ \"command\" : \"version\" }";
    uint32_t len = strlen(buf) + 1;
    [[EADSessionController sharedController] writeData:[NSData dataWithBytes:buf length:len]];
}

#pragma mark UIViewController

- (void)viewWillAppear:(BOOL)animated
{
    // watch for the accessory being disconnected
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
    // watch for received data from the accessory
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sessionDataReceived:) name:EADSessionDataReceivedNotification object:nil];

    EADSessionController *sessionController = [EADSessionController sharedController];

    _accessory = [[sessionController accessory] retain];
    [self setTitle:[sessionController protocolString]];
    [sessionController openSession];
}

- (void)viewWillDisappear:(BOOL)animated
{
    // remove the observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EADSessionDataReceivedNotification object:nil];

    EADSessionController *sessionController = [EADSessionController sharedController];

    [sessionController closeSession];
    [_accessory release];
    _accessory = nil;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.receivedBytesLabel = nil;
    self.stringToSendTextField = nil;
    self.textView = nil;
}

#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark Internal

- (void)_accessoryDidDisconnect:(NSNotification *)notification
{
    if ([[self navigationController] topViewController] == self)
    {
        EAAccessory *disconnectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
        if ([disconnectedAccessory connectionID] == [_accessory connectionID])
        {
            [[self navigationController] popViewControllerAnimated:YES];

        }
    }
}

- (void)_sessionDataReceived:(NSNotification *)notification
{
    EADSessionController *sessionController = (EADSessionController *)[notification object];
    uint32_t bytesAvailable = 0;

    while ((bytesAvailable = [sessionController readBytesAvailable]) > 0) {
        NSData *data = [sessionController readData:bytesAvailable];
        if (data) {
            _totalBytesRead += bytesAvailable;
        }

        // We need to purge null bytes from the received data.
        char* sanitized = malloc(data.length + 1);
        int j = 0;
        for (int i = 0; i < data.length; i++) {
            if (((const char*)data.bytes)[i] == '\0') {
                continue;
            }
            else {
                sanitized[j] = ((const char*)data.bytes)[i];
                j++;
            }
        }
        sanitized[j] = '\0';
        NSString* newString = [_textView.text stringByAppendingString:[NSString stringWithCString:sanitized encoding:NSASCIIStringEncoding] ];

        free(sanitized);

        // Set text view to last 4096 characters received.
        _textView.text = [newString substringFromIndex: MAX(0,(int)[newString length] - 4096)];
        [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length, 0)];
    }

    [_receivedBytesLabel setText:[NSString stringWithFormat:@"Bytes Received from Session: %d", _totalBytesRead]];
}

@end
