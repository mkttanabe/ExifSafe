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

@implementation ViewController

#define IMAGEPICKER_PICTURE  1
#define ALERT_QUERYEXIT      0
#define TEMPIMAGE_FILENAME           @"MyPhoto.jpg"
#define TEMPIMAGERECOMPRESS_FILENAME @"MyPhotoRecomp.jpg"

- (void)viewDidLoad
{
    [super viewDidLoad];
    ifdTableArray = NULL;
    saveJpgFile = nil;
    saveJpgFileRecompress = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self start];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)start {
    if (![UIImagePickerController
         isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [Uty msgBox:NSLocalizedString(@"ImagePickerError", @"") title:APP_NAME];
        return;
    }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    pickerInstance = picker;
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.navigationBar.tag = IMAGEPICKER_PICTURE;
    [self presentViewController:picker animated:YES completion: nil];
}

// delegate method for UIImagePickerController - canceled
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    //_Log(@"ViewController: imagePickerControllerDidCancel");
    UIAlertView *alert =
    [[UIAlertView alloc] initWithTitle:APP_NAME
                               message:NSLocalizedString(@"QueryExit", @"")
                              delegate:self
                     cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                     otherButtonTitles:NSLocalizedString(@"OK", @""), nil];
    alert.tag = ALERT_QUERYEXIT;
    [alert show];
}

// delegate method for UIImagePickerController - finished
- (void)imagePickerController:(UIImagePickerController *)picker
        didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    //_Log(@"picker didFinishPickingMediaWithInfo tag=%d", picker.navigationBar.tag);
    
    // tapped a picture
    if (picker.navigationBar.tag == IMAGEPICKER_PICTURE) {
        NSURL *pickedURL = [info objectForKey:UIImagePickerControllerReferenceURL];
        
        // create temporary image files
        saveJpgFile = [NSTemporaryDirectory()
                       stringByAppendingPathComponent:TEMPIMAGE_FILENAME];
        saveJpgFileRecompress = [NSTemporaryDirectory()
                   stringByAppendingPathComponent:TEMPIMAGERECOMPRESS_FILENAME];
        HandlePhoto *handlePhoto = [[HandlePhoto alloc] init];
        
        BOOL sts = [handlePhoto saveTemporaryJpegFiles:[pickedURL absoluteString]
                                              fileName:saveJpgFile
                                    fileNameRecompress:saveJpgFileRecompress];
        NSString *msg = nil;
        if (!sts) {
            msg = NSLocalizedString(@"TempJpegFileError", @"");
        } else {
            int result;
            ifdTableArray = createIfdTableArray(saveJpgFile.UTF8String, &result);
            //_Log(@"createIfdTableArray result=%d", result);
            switch (result) {
                case ERR_INVALID_JPEG:
                    msg = NSLocalizedString(@"IsNotVaildJpegFile", @"");
                    break;
                case ERR_READ_FILE:
                    msg = NSLocalizedString(@"FileReadError", @"");
                    break;
                case ERR_INVALID_APP1HEADER:
                case ERR_INVALID_IFD:
                    msg = NSLocalizedString(@"IsNotVaildFile", @"");
                    break;
                case 0:
                    msg = NSLocalizedString(@"NotContainsExifData", @"");
                    break;
            }
        }
        if (msg != nil) { // error
            if (ifdTableArray) {
                freeIfdTableArray(ifdTableArray);
                ifdTableArray = NULL;
            }
            NSError *err;
            NSFileManager* fileMan = [NSFileManager defaultManager];
            if ([fileMan fileExistsAtPath:saveJpgFile]) {
                [fileMan removeItemAtPath:saveJpgFile error:&err];
            }
            if ([fileMan fileExistsAtPath:saveJpgFileRecompress]) {
                [fileMan removeItemAtPath:saveJpgFileRecompress error:&err];
            }
            [Uty msgBox:msg title:APP_NAME];
        } else {
            PreviewController *previewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PreviewController"];
            [previewController setDelegate:self];
            [previewController setSavedPhotoInfo:ifdTableArray
                                fileName:saveJpgFile
                      fileNameRecompress:saveJpgFileRecompress];
            // start preview
            [picker presentViewController:previewController
                                 animated:YES completion: nil];
        }
    }
}

// notification from previewController
- (void)PreviewDismissed:(BOOL)YESorNO jpgFileName:(NSString*)jpgFileName {
    //_Log(@"PreviewDismissed val=%d", YESorNO);
    if (ifdTableArray) {
        freeIfdTableArray(ifdTableArray);
        ifdTableArray = NULL;
    }
    NSError *err;
    NSFileManager* fileMan = [NSFileManager defaultManager];
    // delete temporary images
    if (saveJpgFile && [fileMan fileExistsAtPath:saveJpgFile]) {
        [fileMan removeItemAtPath:saveJpgFile error:&err];
    }
    if (saveJpgFileRecompress &&
            [fileMan fileExistsAtPath:saveJpgFileRecompress]) {
        [fileMan removeItemAtPath:saveJpgFileRecompress error:&err];
    }
    // dismiss preview
    [pickerInstance dismissViewControllerAnimated:YES completion: ^{
    }];
}

// delegate method for UIAlertView
- (void)alertView:(UIAlertView*)alertView
                clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == ALERT_QUERYEXIT) {
        if (buttonIndex == 1) { // YES
            [[pickerInstance presentingViewController]
                dismissViewControllerAnimated:YES completion:NULL];
            exit(1); // done
        }
    }
}

@end
