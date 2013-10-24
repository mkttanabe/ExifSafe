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

@implementation Uty

+ (float)getOSVersion
{
    return [[[UIDevice currentDevice] systemVersion] floatValue];
}

+ (BOOL)isSimulator
{
    return [[[UIDevice currentDevice] model] hasSuffix:@"Simulator"];
}

+ (BOOL)isIPad
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

+ (void)msgBox:(NSString*)msg title:(NSString*)title
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:msg
                                                  delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

+ (NSDate*)dateStringToDate:(NSString*)dateStr formatString:(NSString*)formatString {
    NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
	[fmt setDateFormat:formatString];
    NSDate *date = [fmt dateFromString:dateStr];
    return date;
}

+ (NSString*)dateToDateString:(NSDate*)date formatString:(NSString*)formatString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:formatString];
    return [formatter stringFromDate:date];
}

@end
