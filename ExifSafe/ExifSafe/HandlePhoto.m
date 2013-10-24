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
#import "Common.h"

@implementation HandlePhoto

- (int)createNonExifJpegFile:(NSString*)srcJpgFileName outFileName:(NSString*)outFileName
{
    int sts;
    NSString *wk = [srcJpgFileName stringByAppendingString: @"_tmp"];
    
    // remove adobe's XMP metadata
    sts = removeAdobeMetadataSegmentFromJPEGFile([srcJpgFileName UTF8String],
                                                 [wk UTF8String]);
    if (sts <= 0) { // not found or error
        wk = srcJpgFileName;
    }
    sts = removeExifSegmentFromJPEGFile([wk UTF8String], [outFileName UTF8String]);
    if (![wk isEqualToString:srcJpgFileName]) {
        unlink([wk UTF8String]);
    }
    return sts;
}

- (int)createLessExifJpegFile:(NSString*)srcJpgFileName
                  outFileName:(NSString*)outFileName
                ifdTableArray:(void**)ifdTableArray
{
    int sts;
    NSString *wk = [srcJpgFileName stringByAppendingString: @"_tmp"];
    
    // remove adobe's XMP metadata
    sts = removeAdobeMetadataSegmentFromJPEGFile([srcJpgFileName UTF8String],
                                                 [wk UTF8String]);
    if (sts <= 0) { // not found or error
        wk = srcJpgFileName;
    }
    
    removeIfdTableFromIfdTableArray(ifdTableArray, IFD_GPS);
    removeIfdTableFromIfdTableArray(ifdTableArray, IFD_1ST);
    
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_0TH, TAG_Make);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_0TH, TAG_Model);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_0TH, TAG_DateTime);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_0TH, TAG_ImageDescription);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_0TH, TAG_Software);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_0TH, TAG_Artist);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_MakerNote);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_UserComment);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_DateTimeOriginal);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_DateTimeDigitized);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_SubSecTime);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_SubSecTimeOriginal);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_SubSecTimeDigitized);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_ImageUniqueID);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_CameraOwnerName);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_BodySerialNumber);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_LensMake);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_LensModel);
    removeTagNodeFromIfdTableArray(ifdTableArray, IFD_EXIF, TAG_LensSerialNumber);
    
    sts = updateExifSegmentInJPEGFile([wk UTF8String], [outFileName UTF8String], ifdTableArray);
    if (![wk isEqualToString:srcJpgFileName]) {
        unlink([wk UTF8String]);
    }
    return sts;
}

- (int)createOnlyExifOrientationTagJpegFile:(NSString*)srcJpgFileName
                                outFileName:(NSString*)outFileName
                            exifOrientation:(unsigned short)exifOrientation
{
    int sts;
    void **ifdArray = NULL;
    TagNodeInfo *tag = NULL;
    
    ifdArray = insertIfdTableToIfdTableArray(NULL, IFD_0TH, &sts);
    if (!ifdArray) {
        goto DONE;
    }
    tag = createTagInfo(TAG_Orientation, TYPE_SHORT, 1, &sts);
    if (!tag) {
        goto DONE;
    }
    tag->numData[0] = exifOrientation;
    sts = insertTagNodeToIfdTableArray(ifdArray, IFD_0TH, tag);
    if (sts < 0) {
        goto DONE;
    }
    sts = updateExifSegmentInJPEGFile([srcJpgFileName UTF8String], [outFileName UTF8String], ifdArray);
    if (sts < 0) {
        goto DONE;
    }
    sts = 1;
DONE:
    if (tag) {
        freeTagInfo(tag);
    }
    if (ifdArray) {
        freeIfdTableArray(ifdArray);
    }
    return sts;
}


- (BOOL)saveTemporaryJpegFiles:(NSString*)targetAssetURL
                      fileName:(NSString*)fileName
            fileNameRecompress:(NSString*)fileNameRecompress
{
    dispatch_semaphore_t sema = dispatch_semaphore_create(0); // for sync
    __block BOOL sts = NO;

    // e.g. "assets-library://asset/asset.JPG?id=4F5282B7-9111-4AE1-883E-0A601F637515&ext=JPG"
    if (![targetAssetURL hasPrefix:@"assets-library:"]) {
        return sts;
    }
    NSURL* fileURL = [NSURL URLWithString:targetAssetURL];
    ALAssetsLibrary *assetLibrary=[[ALAssetsLibrary alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{  // for sync
        [assetLibrary assetForURL:fileURL
                      resultBlock:^(ALAsset *asset) {
                          UIImage *img;
                          NSData *data;
                          BOOL result;
                          NSError *err;
                          Byte *p = NULL;
                          FILE *fpw = NULL;
                          NSUInteger bufferedLength;
                          
                          // for display (recompress)
                          ALAssetRepresentation *rep = [asset defaultRepresentation];
                          img = [UIImage imageWithCGImage:[rep fullScreenImage]
                                                    scale:[rep scale]
                                              orientation:UIImageOrientationUp];
                          if (!img) {
                              goto DONE;
                          }
                          data = UIImageJPEGRepresentation(img, 0.4f);
                          if (!data) {
                              goto DONE;
                          }
                          result = [data writeToFile:fileNameRecompress atomically:YES];
                          if (!result) {
                              goto DONE;
                          }
                          
                          // for internal processing
                          p = (Byte*)malloc([rep size]);
                          if (!p) {
                              goto DONE;
                          }
                          err = nil;
                          bufferedLength = [rep getBytes:p fromOffset:0.0 length:rep.size error:&err];
                          if (err) {
                              goto DONE;
                          }
                          fpw = fopen([fileName UTF8String], "wb");
                          if (!fpw) {
                              goto DONE;
                          }
                          if (fwrite(p, 1, bufferedLength, fpw) != bufferedLength) {
                              goto DONE;
                          }
                          sts = YES;
DONE:
                          if (fpw) {
                              fclose(fpw);
                          }
                          if (p) {
                              free(p);
                          }
                          dispatch_semaphore_signal(sema); // for sync
                      }
                     failureBlock:^(NSError *err) {
                         _Log(@"Error: %@",[err localizedDescription]);
                         dispatch_semaphore_signal(sema); // for sync
                     }
         ];
    });
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER); // for sync
    dispatch_release(sema);// for sync
    if (!sts) {
        unlink([fileName UTF8String]);
        unlink([fileNameRecompress UTF8String]);
    }
    return sts;
}

@end
