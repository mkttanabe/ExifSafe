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

#import <MessageUI/MFMailComposeViewController.h>

@interface Mail : NSObject <MFMailComposeViewControllerDelegate> {
    id __weak callerInstance;
    BOOL doDeleteAttachFileSource;
    NSArray *attachFilesArray;
}

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
deleteAttachFileSource:(BOOL)deleteAttachFileSource;

@end
