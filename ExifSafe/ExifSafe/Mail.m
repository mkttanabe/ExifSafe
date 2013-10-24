/*
 * Copyright (C) 2013 KLab Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "Common.h"

@implementation Mail

-(BOOL)createMail:(id)caller
            delegate:(id)delegate // nil = default
             useHtml:(BOOL)useHtml
             subject:(NSString*)subject
             message:(NSString*)msg
                  to:(NSArray*)to
                  cc:(NSArray*)cc
                 bcc:(NSArray*)bcc
         attachFiles:(NSArray*)attachFiles
     attachFileNames:(NSArray*)attachFileNames
     attachFileTypes:(NSArray*)attachFileTypes
deleteAttachFileSource:(BOOL)deleteAttachFileSource
{
    if(![MFMailComposeViewController canSendMail]) {
        UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:APP_NAME
                                   message:NSLocalizedString(@"MailerError", @"")
                                  delegate:self
                         cancelButtonTitle:NSLocalizedString(@"OK", @"")
                         otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    callerInstance = caller;
    doDeleteAttachFileSource = deleteAttachFileSource;
    
    if (doDeleteAttachFileSource && attachFiles && [attachFiles count] > 0) {
        attachFilesArray = [NSArray arrayWithArray:attachFiles];
    }
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = (delegate == nil) ? self : delegate;
    
    // subject to cc bcc
    [picker setSubject:subject];
    [picker setToRecipients:to];
    [picker setCcRecipients:cc];
    [picker setBccRecipients:bcc];
    
    // message
    NSString *emailBody = msg;
    
    // HTML mail or not
    [picker setMessageBody:emailBody isHTML:useHtml];
    
    if (attachFiles != nil) {
        NSUInteger num = [attachFiles count];
        for (int i = 0; i < num; i++) {
            NSString *path = [attachFiles objectAtIndex:i];
            NSString *name = [attachFileNames objectAtIndex:i];
            NSString *type = [attachFileTypes objectAtIndex:i];
            NSData* fileData = [NSData dataWithContentsOfFile:path];
            [picker addAttachmentData:fileData mimeType:type fileName:name];
        }
    }
    // start mailer UI
    [callerInstance presentModalViewController:picker animated:YES];
    return YES;
}

// default delegate method
- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error
{
    UIAlertView *alert;
    switch (result){
        case MFMailComposeResultCancelled:
            break;
        case MFMailComposeResultSaved:
            break;
        case MFMailComposeResultSent:
            break;
        case MFMailComposeResultFailed:
            alert =
            [[UIAlertView alloc] initWithTitle:APP_NAME
                                       message:NSLocalizedString(@"SendError", @"")
                                      delegate:self
                             cancelButtonTitle:NSLocalizedString(@"OK", @"")
                             otherButtonTitles:nil];
            [alert show];
            return;
    }
    // delete files if needed
    if (doDeleteAttachFileSource && attachFilesArray) {
        int num = [attachFilesArray count];
        if (num > 0) {
            for (int i = 0; i < num; i++) {
                NSString *file = [attachFilesArray objectAtIndex:i];
                unlink([file UTF8String]);
            }
        }
    }
    // finish
    [callerInstance dismissModalViewControllerAnimated:YES];
    callerInstance = nil;
}

@end
