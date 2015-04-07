//
//  ViewController.m
//  KBContactsSelectionExample
//
//  Created by Kamil Burczyk on 13.12.2014.
//  Copyright (c) 2014 Sigmapoint. All rights reserved.
//

#import "ViewController.h"
#import "KBContactsSelectionViewController.h"
#import <APAddressBook/APContact.h>
#import <APAddressBook/APPhoneWithLabel.h>
#import <SVProgressHUD.h>

@interface ViewController () <KBContactsSelectionViewControllerDelegate>
@property (weak) KBContactsSelectionViewController* presentedCSVC;
@property (strong) NSArray * fakeCache;
@end

@implementation ViewController

- (IBAction)push:(UIButton *)sender {
    
    __block KBContactsSelectionViewController *vc = [KBContactsSelectionViewController contactsSelectionViewControllerWithConfiguration:^(KBContactsSelectionConfiguration *configuration) {
        configuration.shouldShowNavigationBar = NO;
        configuration.tintColor = [UIColor colorWithRed:11.0/255 green:211.0/255 blue:24.0/255 alpha:1];
        configuration.title = @"Push";
        configuration.selectButtonTitle = @"Message";
        
        configuration.mode = KBContactsSelectionModeMessages;
        configuration.skipUnnamedContacts = YES;

        configuration.contactEnabledValidation = ^(id contact) {
            APContact * _c = contact;
            if ([_c phonesWithLabels].count > 0) {
                NSString * phone = ((APPhoneWithLabel*) _c.phonesWithLabels[0]).phone;
                if ([phone containsString:@"888"]) {
                    return NO;
                }
            }
            return YES;
        };
    }];
    [vc setDelegate:self];
    [self.navigationController pushViewController:vc animated:YES];
    self.presentedCSVC = vc;
    
    __block UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 24)];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"Select people you want to text";

    vc.additionalInfoView = label;
}

- (IBAction)present:(UIButton *)sender {
    
    __block KBContactsSelectionViewController *vc = [KBContactsSelectionViewController contactsSelectionViewControllerWithConfiguration:^(KBContactsSelectionConfiguration *configuration) {
        configuration.tintColor = [UIColor orangeColor];
        configuration.mode = KBContactsSelectionModeEmail;
        configuration.title = @"Present";
        configuration.selectButtonTitle = @"Compose";
    }];
    
    
    [vc setDelegate:self];
    [self presentViewController:vc animated:YES completion:nil];
    self.presentedCSVC = vc;
    
    __block UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 24)];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"Select people you want to email";
    
    vc.additionalInfoView = label;
}


- (IBAction)combined:(UIButton *)sender {
    
    __block KBContactsSelectionViewController *vc = [KBContactsSelectionViewController contactsSelectionViewControllerWithConfiguration:^(KBContactsSelectionConfiguration *configuration) {
        configuration.tintColor = [UIColor orangeColor];
        configuration.mode = KBContactsSelectionModeEmail;
        configuration.title = @"Present";
        configuration.selectButtonTitle = @"Custom";

        configuration.customSelectButtonHandler = ^(NSArray * contacts) {
            NSLog(@"This is a custom block for %@", contacts);
        };
        
        configuration.storeCache = ^(NSArray * apContacts) {
            self.fakeCache = apContacts;
        };
        configuration.restoreCache = ^NSArray *(void) {
            return self.fakeCache;
        };
        
    }];
    
    
    [vc setDelegate:self];
    [self presentViewController:vc animated:YES completion:nil];
    self.presentedCSVC = vc;
    
    __block UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 24)];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"Select people you want to email";
    
    vc.additionalInfoView = label;
}

#pragma mark - KBContactsSelectionViewControllerDelegate
- (void) contactsSelection:(KBContactsSelectionViewController*)selection didSelectContact:(APContact *)contact {
    
    __block UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 36)];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [NSString stringWithFormat:@"%@ Selected", @(self.presentedCSVC.selectedContacts.count)];
    
    self.presentedCSVC.additionalInfoView = label;
    
    NSLog(@"%@", self.presentedCSVC.selectedContacts);
}

- (void) contactsSelection:(KBContactsSelectionViewController*)selection didRemoveContact:(APContact *)contact {
    
    __block UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 36)];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [NSString stringWithFormat:@"%@ Selected", @(self.presentedCSVC.selectedContacts.count)];
    
    self.presentedCSVC.additionalInfoView = label;
    
    NSLog(@"%@", self.presentedCSVC.selectedContacts);
}

- (void)contactsSelectionWillLoadContacts:(KBContactsSelectionViewController *)csvc
{
    [SVProgressHUD showWithStatus:@"Loading..."];
}
- (void)contactsSelectionDidLoadContacts:(KBContactsSelectionViewController *)csvc
{
    [SVProgressHUD dismiss];
}
- (void) contactsSelectionRestoredCachedContacts:(KBContactsSelectionViewController *)csvc
{
    NSLog(@"contactsSelectionRestoredCachedContacts:");
}
- (void) contactsSelectionUpdatedCachedContacts:(KBContactsSelectionViewController *)csvc
{
    NSLog(@"contactsSelectionUpdatedCachedContacts:");
}
@end
