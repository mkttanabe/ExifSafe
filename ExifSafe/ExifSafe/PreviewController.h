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

#import <MapKit/MapKit.h>

@protocol PreviewDelegate
- (void) PreviewDismissed:(BOOL)YESorNo jpgFileName:(NSString*)jpgFileName;
@end

@interface PreviewController : UIViewController <MKMapViewDelegate> {
    id __weak delegate;
    void **ifdTableArray;
    NSString *savedJpgFile;
    NSString *savedJpgFileRecompress;
    NSString *nonExifJpgFile;
    NSString *exifData;
    NSString *photoDate;
    int photoOrientation;
    CLLocationDegrees latitude;
    CLLocationDegrees longitude;
    BOOL mapInitialized;
    UIActivityIndicatorView *indicator;
}
@property (weak, nonatomic) id delegate;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIButton *buttonCancel;
@property (weak, nonatomic) IBOutlet UIButton *buttonUse;
@property (weak, nonatomic) IBOutlet UIButton *buttonData;
@property (weak, nonatomic) IBOutlet UIButton *buttonMap;
@property (weak, nonatomic) IBOutlet UITextView *texViewMetaData;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;

- (void)setSavedPhotoInfo:(void**)ifdArray fileName:fileName fileNameRecompress:fileNameRecompress;
- (IBAction)pushedUseButton:(id)sender;
- (IBAction)pushedCancelButton:(id)sender;
- (IBAction)pushedDataButton:(id)sender;
- (IBAction)pushedMapButton:(id)sender;

@end
