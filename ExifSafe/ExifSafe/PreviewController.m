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

#import <AssetsLibrary/ALAssetRepresentation.h>
#import <ImageIO/ImageIO.h>
#import "Common.h"

@implementation PreviewController
@synthesize delegate;

#define QUERY_DOWHAT 0
#define QUERY_MAIL   1
#define QUERY_COPY   2

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setup];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    UIDeviceOrientation orientation =
        (UIDeviceOrientation)[[UIApplication sharedApplication] statusBarOrientation];
    [self adjustControlls:orientation];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)setSavedPhotoInfo:(void**)ifdArray
                 fileName:fileName
       fileNameRecompress:fileNameRecompress
{
    ifdTableArray = ifdArray;
    savedJpgFile = fileName;
    savedJpgFileRecompress = fileNameRecompress;
}

// iOS 5.x
- (BOOL)shouldAutorotateToInterfaceOrientation:
                            (UIInterfaceOrientation)interfaceOrientation
{
    UIDeviceOrientation orientation =
                    (UIDeviceOrientation)interfaceOrientation;
    if (orientation == UIDeviceOrientationPortrait ||
        orientation == UIDeviceOrientationLandscapeLeft ||
        orientation == UIDeviceOrientationLandscapeRight) {
        [self adjustControlls:orientation];
        return YES;
    }
    return NO;
}

// iOS 6.x -
- (BOOL)shouldAutorotate {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    return [self shouldAutorotateToInterfaceOrientation:
                                (UIInterfaceOrientation)orientation];
}

// start
- (void)setup
{
    // UIActivityIndicatorView
    if (indicator == nil) {
        CGRect rect = CGRectMake(0, 0, 100, 100);
        indicator = [[UIActivityIndicatorView alloc]initWithFrame:rect];
        indicator.center = self.view.center;
        indicator.activityIndicatorViewStyle =
                            UIActivityIndicatorViewStyleWhiteLarge;
        [self.view addSubview:indicator];
    }

    nonExifJpgFile = [NSTemporaryDirectory()
                      stringByAppendingPathComponent:@"_nonexif.jpg"];
    exifData = nil;
    latitude = 0;
    longitude = 0;
    photoDate = @"photo";
    mapInitialized = NO;

    if (ifdTableArray) {
        // get dump of ifdTableArray
        for (int i = 0; ifdTableArray[i] != NULL; i++) {
            char *p = NULL;
            getIfdTableDump(ifdTableArray[i], &p);
            if (p) {
                if (!exifData) {
                    exifData = [NSString stringWithCString:p
                                                 encoding:NSUTF8StringEncoding];
                } else {
                    NSString *newStr = [NSString stringWithCString:p
                                                 encoding:NSUTF8StringEncoding];
                    exifData = [exifData stringByAppendingString: newStr];
                }
                free(p);
            }
        }
        // get Exif DateTime value
        NSString *dateTimeStr = [self getPhotoDate:ifdTableArray];
        if (dateTimeStr) {
            // convert datetime format
            NSDate *date = [Uty dateStringToDate:dateTimeStr
                                    formatString:@"yyyy:MM:dd HH:mm:ss"];
            photoDate = [Uty dateToDateString:date
                                 formatString:@"yyyy-MM-dd HH.mm.ss"];
        }
        // get Exif Orientation value
        photoOrientation = [self getPhotoOrientation:ifdTableArray];
        // get Exif GPS data
        [self getPhotoPosition:ifdTableArray];
    }

    NSURL *jpgUrl = [NSURL fileURLWithPath:savedJpgFileRecompress];
    NSURLRequest *req = [NSURLRequest requestWithURL:jpgUrl];
    // allow pinch zoom
    self.webView.scalesPageToFit = YES;
    // background color
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.opaque = NO;
    // load image to webView
    [self.webView loadRequest:req];

    // set Exif metadata to textView
    [self.texViewMetaData setHidden:YES];
    [self initMetaDataTextView:exifData];
    
    // mapView initial state
    [self.mapView setHidden:YES];
    
    // label of buttons
    [self.buttonCancel setTitle:NSLocalizedString(@"ButtonTitleCancel", @"")
                       forState:UIControlStateNormal];
    [self.buttonData setTitle:NSLocalizedString(@"ButtonTitleExif", @"")
                     forState:UIControlStateNormal];
    [self.buttonMap setTitle:NSLocalizedString(@"ButtonTitleMap", @"")
                    forState:UIControlStateNormal];
    [self.buttonUse setTitle:NSLocalizedString(@"ButtonTitleUse", @"")
                    forState:UIControlStateNormal];

    // translucent buttons
    [self.buttonCancel setAlpha:0.8];
    [self.buttonData setAlpha:0.8];
    [self.buttonMap setAlpha:0.8];
    [self.buttonUse setAlpha:0.8];
         
    // disable "Exif" button if Exif data does not exist
    if (!exifData) {
        [self.buttonData setEnabled:NO];
        [self.buttonData setTitleColor:
                [UIColor blackColor] forState:UIControlStateNormal];
    }

    // disable "Map" button if GPS data does not exist
    if (latitude == 0 && longitude == 0) {
        [self.buttonMap setEnabled:NO];
        [self.buttonMap setTitleColor:
                [UIColor darkGrayColor] forState:UIControlStateNormal];
    }
}

// finish
- (void)doneModal:(BOOL)retValue
{
    unlink([nonExifJpgFile UTF8String]);
    // notification to the caller
    if ([delegate respondsToSelector:@selector(PreviewDismissed:jpgFileName:)]) {
        [delegate PreviewDismissed:retValue jpgFileName:savedJpgFile];
    }
}

// "Cancel" button handler
- (IBAction)pushedCancelButton:(id)sender
{
    [self doneModal:NO];
}

// "Exif" button handler
- (IBAction)pushedDataButton:(id)sender
{
    BOOL force = NO;
    // hide mapView if it is showing
    if (![self.mapView isHidden]) {
        [self.mapView setHidden:YES];
        force = YES;
    }
    if ([self.texViewMetaData isHidden] || force) {
        [self.texViewMetaData setHidden:NO];
        self.webView.alpha = 0.4f;
    } else {
        [self.texViewMetaData setHidden:YES];
        self.webView.alpha = 1;
    }
}

// "Map" button handler
- (IBAction)pushedMapButton:(id)sender
{
    [self showMap];
}

// "Use" button handler
- (IBAction)pushedUseButton:(id)sender
{
    [self queryDoWhat];
}

// confirm the operation
- (void)queryDoWhat
{
    UIAlertView *alertView =
    [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"SelectOperation", @"")
                               message:@""
                              delegate:self
                     cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                     otherButtonTitles:NSLocalizedString(@"SendPicture", @""),
                        NSLocalizedString(@"CopyPicture", @""), nil];
    alertView.tag = QUERY_DOWHAT;
    [alertView show];
}

// confirm the mail operation
- (void)queryMail
{
    NSString *title = [NSString stringWithFormat:
                       NSLocalizedString(@"SendPictureAs", @""), photoDate];
    UIAlertView *alertView =
    [[UIAlertView alloc] initWithTitle:title
                               message:NSLocalizedString(@"SendPictureMsg", @"")
                              delegate:self
                     cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                     otherButtonTitles:NSLocalizedString(@"SendPictureNoExif", @""),
                        NSLocalizedString(@"SendPictureCutExif", @""),
                        NSLocalizedString(@"SendPictureOrigin", @""), nil];
    alertView.tag = QUERY_MAIL;
    [alertView show];
}

// confirm the copy operation
- (void)queryCopy
{
    NSString *title = NSLocalizedString(@"CopyPicture", @"");
    UIAlertView *alertView =
    [[UIAlertView alloc] initWithTitle:title
                               message:NSLocalizedString(@"CopyPicutureMsg", @"")
                              delegate:self
                     cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                     otherButtonTitles:NSLocalizedString(@"CopyPictureNoExif", @""),
                        NSLocalizedString(@"CopyPictureCutExif", @""), nil];
    alertView.tag = QUERY_COPY;
    [alertView show];
}

// delegate method for AlertView
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    int sts;
    NSString *msg, *text;
    HandlePhoto *handlePhoto = [[HandlePhoto alloc] init];

    if (alertView.tag == QUERY_DOWHAT) {
        if (buttonIndex == 1) { // mail
            [self queryMail];
        }
        else if (buttonIndex == 2) { // copy
            [self queryCopy];
        }
    }
    else if (alertView.tag == QUERY_COPY) {
        if (buttonIndex == 0) { // cancel
            [self queryDoWhat];
            return;
        }
        
        NSString *myGroupName = APP_NAME;
        __block NSURL *myGroupURL = nil;
        NSMutableDictionary *metadata = nil;
        [self HideButtons:YES];
        [indicator startAnimating];
        
        sts = -1;
        if (buttonIndex == 1) { // create a copy excluding the Exif data
            sts = [handlePhoto createNonExifJpegFile:savedJpgFile
                                         outFileName:nonExifJpgFile];
            if (sts < 0) {
                [indicator stopAnimating];
                [self HideButtons:NO];
                [self showError:@"TempFileError" status:sts];
                return;
            }
            if (photoOrientation != 1) {
                metadata = [NSMutableDictionary dictionary];
                [metadata setObject:[NSNumber numberWithShort:photoOrientation]
                             forKey:(NSString *)kCGImagePropertyOrientation];
            }
        }
        else if (buttonIndex == 2) { // exclude sensitive Exif data
            sts = [handlePhoto createLessExifJpegFile:savedJpgFile
                                          outFileName:nonExifJpgFile
                                        ifdTableArray:ifdTableArray];
            if (sts < 0) {
                [indicator stopAnimating];
                [self HideButtons:NO];
                [self showError:@"TempFileError" status:sts];
                return;
            }
            // get Exif metadata from output JPEG file
            CGImageSourceRef srcRef =
                CGImageSourceCreateWithURL((__bridge CFURLRef)
                                [NSURL fileURLWithPath:nonExifJpgFile], nil);
            metadata = (__bridge NSMutableDictionary *)
                            CGImageSourceCopyPropertiesAtIndex(srcRef, 0, nil);
        }
        // add new JPEG file to the album
        ALAssetsLibrary *al = [[ALAssetsLibrary alloc] init];
        myGroupURL = [self getAlbumGroupURL:myGroupName];
        if (myGroupURL == nil) {
            myGroupURL = [self createAlbumGroup:myGroupName];
        }
        UIImage *uim = [UIImage imageWithContentsOfFile:nonExifJpgFile];
        [al writeImageToSavedPhotosAlbum:[uim CGImage]
                                metadata:metadata
                         completionBlock:^(NSURL *assetURL, NSError *error){
                             if (error) {
                                 [indicator stopAnimating];
                                 [self HideButtons:NO];
                                 [Uty msgBox:NSLocalizedString(@"SaveError", @"") title:APP_NAME];
                             } else {
                                 // add asset to the album
                                 [self addAssetURL:assetURL AlbumURL:myGroupURL];
                                 [indicator stopAnimating];
                                 [self HideButtons:NO];
                                 NSString *mesg =
                                 [NSString stringWithFormat:NSLocalizedString(@"SaveDone", @""), APP_NAME];
                                 [Uty msgBox:mesg title:APP_NAME];
                             }
                         }
         ];
    }
    else if (alertView.tag == QUERY_MAIL) {
        if (buttonIndex == 0) { // cancel
            [self queryDoWhat];
        }
        else if (buttonIndex == 1) { // remove all Exif data
            sts = [handlePhoto createNonExifJpegFile:savedJpgFile
                                         outFileName:nonExifJpgFile];
            if (sts < 0) {
                [self showError:@"TempFileError" status:sts];
                return;
            }
            if (photoOrientation == 1) {
                [self doMail:nonExifJpgFile message:
                    NSLocalizedString(@"JPEGhasNoExif", @"")];
                
            } else {
                // insert Exif Orientation tag in order to avoid confusion
                NSString *tempJpg = [NSTemporaryDirectory()
                                    stringByAppendingPathComponent:@"temp.jpg"];
                sts = [handlePhoto
                       createOnlyExifOrientationTagJpegFile:nonExifJpgFile
                                                outFileName:tempJpg
                                            exifOrientation:photoOrientation];
                if (sts < 0) {
                    [self showError:@"TempFileError" status:sts];
                    return;
                }
                unlink([nonExifJpgFile UTF8String]);
                rename([tempJpg UTF8String], [nonExifJpgFile UTF8String]);
                [self doMail:nonExifJpgFile message:
                            NSLocalizedString(@"JPEGhasNoExifPlus", @"")];
            }
        }
        else if (buttonIndex == 2) { // remove sensitive Exif data only
            sts = [handlePhoto createLessExifJpegFile:savedJpgFile
                                          outFileName:nonExifJpgFile
                                        ifdTableArray:ifdTableArray];
            if (sts < 0) {
                [self showError:@"TempFileError" status:sts];
                return;
            }
            // get dump of updated ifdTableArray
            NSString *dumpData = nil;
            for (int i = 0; ifdTableArray[i] != NULL; i++) {
                char *p = NULL;
                getIfdTableDump(ifdTableArray[i], &p);
                if (p) {
                    if (!dumpData) {
                        dumpData = [NSString stringWithCString:p
                                            encoding:NSUTF8StringEncoding];
                    } else {
                        NSString *newStr = [NSString stringWithCString:p
                                            encoding:NSUTF8StringEncoding];
                        dumpData = [dumpData stringByAppendingString: newStr];
                    }
                    free(p);
                }
            }
            msg = NSLocalizedString(@"JPEGhasLessExif", @"");
            text = [msg stringByAppendingString:dumpData];
            [self doMail:nonExifJpgFile message: text];
        }
        else if (buttonIndex == 3) { // attach orijinal photo
            msg = NSLocalizedString(@"JPEGhasExif", @"");
            text = [msg stringByAppendingString:exifData];
            [self doMail:savedJpgFile message:text];
        }
    }
}

// notification of finished loading a map
- (void)mapViewDidFinishLoadingMap:(MKMapView*)mapView {
    // show callout bubble without tapping
    [mapView selectAnnotation:[mapView.annotations lastObject] animated:YES];
    mapInitialized = YES;
}

// show/hide mapView
- (void)showMap
{
    if ([self.mapView isHidden]) {
        [self.mapView setHidden:NO];
        if (mapInitialized) {
            return;
        }
        [self.mapView setMapType:MKMapTypeStandard];
        [self.mapView setZoomEnabled:YES];
        [self.mapView setScrollEnabled:YES];
        
        // set the latitude and the longitude
        Annotation *anno = [[Annotation alloc] init];
        anno.coordinate = CLLocationCoordinate2DMake(latitude, longitude);
        anno.title = NSLocalizedString(@"Location", @"");
        anno.subtitle = [NSString stringWithFormat:
                    NSLocalizedString(@"LatAndLon", @""), latitude, longitude];
        [self.mapView addAnnotation:anno];
        [self.mapView setCenterCoordinate:anno.coordinate animated:YES];
        // set the region
        MKCoordinateRegion region;
        region.center = anno.coordinate;
        region.span.latitudeDelta = 0.4;
        region.span.longitudeDelta = 0.4;
        [self.mapView setRegion:region animated:YES];
        [self.mapView setDelegate:self];
    } else {
        [self.mapView setHidden:YES];
    }
}

// start mailer UI
- (void)doMail:(NSString*)jpgFileName message:(NSString*)message
{
    NSString *jpgName = [photoDate stringByAppendingString:@".jpg"];
    NSArray *attachFiles = [NSArray arrayWithObjects:jpgFileName, nil];
    NSArray *attachFileNames = [NSArray arrayWithObjects:jpgName, nil];
    NSArray *attachFileTypes = [NSArray arrayWithObjects:@"image/jpeg", nil];
    Mail *mail = [[Mail alloc] init];
    
    [mail createMail:self
            delegate:self
             useHtml:NO
             subject:jpgName
             message:message
                  to:nil
                  cc:nil
                 bcc:nil
         attachFiles:attachFiles
     attachFileNames:attachFileNames
     attachFileTypes:attachFileTypes
deleteAttachFileSource:NO];
}

// mail compose view controller delegate method
- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error {
    switch (result){
        case MFMailComposeResultCancelled:
            break;
        case MFMailComposeResultSaved:
            break;
        case MFMailComposeResultSent:
            break;
        case MFMailComposeResultFailed:
            [Uty msgBox:NSLocalizedString(@"SendError", @"") title:APP_NAME];
            break;
    }
    // finish mailer UI
    [self dismissViewControllerAnimated:YES completion: ^{
        [self doneModal:YES];
    }];
}

// get the URL of the album
- (NSURL*)getAlbumGroupURL:(NSString *)groupName
{
    __block NSURL *myGroupURL = nil;
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0); // for sync
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{  // for sync
        [library enumerateGroupsWithTypes:ALAssetsGroupAlbum
                               usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                   if (group) {
                                       NSString *name =
                                       [group valueForProperty:ALAssetsGroupPropertyName];
                                       if ([name isEqualToString:groupName]) {
                                           myGroupURL =
                                           [group valueForProperty:ALAssetsGroupPropertyURL];
                                       }
                                   } else { // enumeration completed
                                       dispatch_semaphore_signal(sema); // for sync
                                   }
                               } failureBlock:^(NSError *err){
                                   dispatch_semaphore_signal(sema); // for sync
                               }
         ];
    });
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER); // for sync
    dispatch_release(sema);
    return myGroupURL;
}

// create an album
- (NSURL*)createAlbumGroup:(NSString *)groupName
{
    __block NSURL *myGroupURL = nil;
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{  // for sync
        [library addAssetsGroupAlbumWithName:groupName
                                 resultBlock:^(ALAssetsGroup *group) {
                                     myGroupURL =
                                     [group valueForProperty:ALAssetsGroupPropertyURL];
                                     dispatch_semaphore_signal(sema); // for sync
                                 } failureBlock:^(NSError *err){
                                     dispatch_semaphore_signal(sema); // for sync
                                 }
         ];
    });
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER); // for sync
    dispatch_release(sema);
    return myGroupURL;
}

// add asset to the album
- (void)addAssetURL:(NSURL*)assetURL AlbumURL:(NSURL *)albumURL
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{  // for sync
        // get Group from albumURL
        [library groupForURL:albumURL
                 resultBlock:^(ALAssetsGroup *group){
                     // get asset from assetURL
                     [library assetForURL:assetURL
                              resultBlock:^(ALAsset *asset) {
                                  if (group.editable) {
                                      // add asset to the Group
                                      [group addAsset:asset];
                                      dispatch_semaphore_signal(sema); // for sync
                                  }
                              } failureBlock:^(NSError *err){
                                  dispatch_semaphore_signal(sema); // for sync
                              }
                      ];
                 } failureBlock:^(NSError *err){
                     dispatch_semaphore_signal(sema); // for sync
                 }
         ];
    });
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER); // for sync
    dispatch_release(sema);
}

-(void)adjustControlls:(UIDeviceOrientation)orientation;
{
    CGRect r = [[UIScreen mainScreen] bounds];
    CGFloat w = r.size.width;
    CGFloat h = r.size.height;
    
    CGRect rCancel = [self.buttonCancel bounds];
    CGRect rData = [self.buttonData bounds];
    CGRect rMap = [self.buttonMap bounds];
    CGRect rUse = [self.buttonUse bounds];
    
    int margin = rCancel.size.height;
    int unitX;
    if (orientation == UIDeviceOrientationPortrait) {
        unitX = w / 4;
        rCancel.origin.y = h - rCancel.size.height - margin;
    } else {
        unitX = h / 4;
        rCancel.origin.y = w - rCancel.size.height - margin;
    }
    // Cancel button
    rCancel.origin.x =  (unitX - rCancel.size.width) / 2;
    
    // Exif button
    rData.origin.x = unitX + (unitX - rData.size.width) / 2;
    rData.origin.y = rCancel.origin.y;
    
    // Map button
    rMap.origin.x = unitX * 2 + (unitX - rMap.size.width) / 2;
    rMap.origin.y = rCancel.origin.y;
    
    // Use button
    rUse.origin.x = unitX * 3 + (unitX - rUse.size.width) / 2;
    rUse.origin.y = rCancel.origin.y;
    
    [self.buttonCancel setFrame:rCancel];
    [self.buttonData setFrame:rData];
    [self.buttonMap setFrame:rMap];
    [self.buttonUse setFrame:rUse];
    
    // metadata area
    [self.texViewMetaData setFont:[UIFont systemFontOfSize:15]];
    CGRect rTextView = [self.texViewMetaData bounds];
    if (orientation == UIDeviceOrientationPortrait) {
        rTextView.size.height = h;
    } else {
        rTextView.size.height = w;
    }
    rTextView.origin.y = 0;
    [self.texViewMetaData setFrame:rTextView];
    if (rTextView.size.width > w) {
        [self.texViewMetaData
         setContentSize:CGSizeMake(rTextView.size.width * 4/3,
                                   self.texViewMetaData.contentSize.height)];
    }
    // Map
    CGRect rMapView = [self.mapView bounds];
    if (orientation == UIDeviceOrientationPortrait) {
        rMapView.size.width = w;
        rMapView.size.height = h;
    } else {
        rMapView.size.width = h;
        rMapView.size.height = w;
    }
    rMapView.origin.x = rMapView.origin.y = 0;
    [self.mapView setFrame:rMapView];
}

- (void)initMetaDataTextView:(NSString*)metaText
{
    int minFontSize = 16;
    NSString *fontName = @"Courier";
    CGRect r = [[UIScreen mainScreen] bounds];
    CGFloat w = r.size.width;
    CGFloat h = r.size.height;
    CGRect rTextView = [self.texViewMetaData bounds];
    
    // search the longest line
    int max = 0;
    NSString *maxStr;
    NSArray *lines = [metaText componentsSeparatedByString:@"\n"]; // split
    for (int i = 0; i < lines.count; i++) {
        NSString *str = [lines objectAtIndex:i];
        if (max < str.length) {
            max = str.length;
            maxStr = str;
        }
    }
    [self.texViewMetaData setText:[metaText stringByAppendingString:@"\n\n\n\n"]];
    
    // get maximum line width
    UIFont *f = [UIFont fontWithName:fontName size:minFontSize];
    CGSize size = [maxStr sizeWithFont:f];
    
    if (size.width > w) {
        self.texViewMetaData.font = f;
        // expand the width of textView to avoid word wrapping
        rTextView.size.width = size.width * 4/3;
        [self.texViewMetaData setFrame:rTextView];
        [self.texViewMetaData setContentSize:
                CGSizeMake(rTextView.size.width * 10,
                           self.texViewMetaData.contentSize.height)];
    }
    else {
        // determine the font size to fit the longest line in
        // about 3/4 width of the screen
        float limit = w * 3/4;
        int n = 0;
        while (size.width < limit) {
            f = [UIFont fontWithName:fontName size:minFontSize+(n++)];
            size = [maxStr sizeWithFont:f];
        }
        self.texViewMetaData.font = f;
        rTextView.size.width = w;
        rTextView.size.height = h;
        [self.texViewMetaData setFrame:rTextView];
    }
}

// get the Exif "Orientation" value
- (int)getPhotoOrientation:(void*)ifdArray
{
    int orientation = 1;
    TagNodeInfo *tag = getTagInfo(ifdArray, IFD_0TH, TAG_Orientation);
    if (tag) {
        if (!tag->error) {
            orientation = (int)tag->numData[0];
        }
        freeTagInfo(tag);
    }
    return orientation;
}

// get the Exif "DateTime" value
- (NSString*)getPhotoDate:(void*)ifdArray
{
    NSString *date = nil;
    int IFDs[4] = {IFD_EXIF, IFD_EXIF, IFD_0TH, -1};
    int TAGs[4] = {TAG_DateTimeOriginal, TAG_DateTimeDigitized, TAG_DateTime, -1};
    
    for (int i = 0; TAGs[i] != -1; i++) {
        TagNodeInfo *tag = getTagInfo(ifdArray, IFDs[i], TAGs[i]);
        if (tag) {
            if (!tag->error) {
                date = [NSString stringWithCString:(char*)tag->byteData
                                          encoding:NSUTF8StringEncoding];
                date = [date stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceCharacterSet]];
                if (date.length <= 0) {
                    date = nil;
                }
            }
            freeTagInfo(tag);
        }
        if (date) {
            break;
        }
    }
    return date;
}

// get the Exif "GPSLatitude" "GPSLongitude" value
- (BOOL)getPhotoPosition:(void*)ifdArray
{
    int latr = 0, longir = 0l;
    CLLocationDegrees lat[3], longi[3];
    TagNodeInfo *tag = getTagInfo(ifdArray, IFD_GPS, TAG_GPSLatitudeRef);
    if (!tag) {
        return NO;
    }
    if (tag->error) {
        freeTagInfo(tag);
        return NO;
    }
    latr = (tag->byteData[0] == 'N') ? 1 : -1;
    freeTagInfo(tag);
    tag = getTagInfo(ifdArray, IFD_GPS, TAG_GPSLongitudeRef);
    if (!tag) {
        return NO;
    }
    if (tag->error) {
        freeTagInfo(tag);
        return NO;
    }
    longir = (tag->byteData[0] == 'E') ? 1 : -1;
    freeTagInfo(tag);
    tag = getTagInfo(ifdArray, IFD_GPS, TAG_GPSLatitude);
    if (!tag) {
        return NO;
    }
    if (tag->error) {
        freeTagInfo(tag);
        return NO;
    }
    for (int i = 0; i < tag->count; i++) {
        lat[i] = (double)tag->numData[i*2] / (double)tag->numData[i*2+1];
    }
    freeTagInfo(tag);
    tag = getTagInfo(ifdArray, IFD_GPS, TAG_GPSLongitude);
    if (!tag) {
        return NO;
    }
    if (tag->error) {
        freeTagInfo(tag);
        return NO;
    }
    for (int i = 0; i < tag->count; i++) {
        longi[i] = (double)tag->numData[i*2] / (double)tag->numData[i*2+1];
    }
    freeTagInfo(tag);
    
    latitude = (lat[0] + lat[1]/60 + lat[2]/3600) * latr;
    longitude = (longi[0] + longi[1]/60 + longi[2]/3600) * longir;

    return YES;
}

- (void)showError:(NSString *)fmtStringId status:(int)status
{
    NSString *msg = [NSString stringWithFormat:
                     NSLocalizedString(fmtStringId, @""), status];
    [Uty msgBox:msg title:APP_NAME];
}

- (void)HideButtons:(BOOL)YESorNo
{
    [self.buttonCancel setHidden:YESorNo];
    [self.buttonData setHidden:YESorNo];
    [self.buttonMap setHidden:YESorNo];
    [self.buttonUse setHidden:YESorNo];
}

@end
