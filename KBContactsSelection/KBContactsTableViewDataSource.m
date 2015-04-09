//
//  KBContactsTableViewDataSource.m
//  KBContactsSelectionExample
//
//  Created by Kamil Burczyk on 13.12.2014.
//  Copyright (c) 2014 Sigmapoint. All rights reserved.
//

#import "KBContactsTableViewDataSource.h"
#import "KBContactCell.h"
#import "APContact+FullName.h"
#import "APPhoneWithLabel.h"

@interface KBContactsTableViewDataSource()

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) KBContactsSelectionConfiguration *configuration;

@property (nonatomic, strong) NSArray *unfilteredContacts;
@property (nonatomic, strong) NSString *lastSearch;
@property (nonatomic, strong) NSMutableArray *selectedContactsRecordIds;
@property (nonatomic, strong) NSMutableArray *selectedRows;
@property (nonatomic, strong) NSArray *sectionIndexTitles;
@property (nonatomic, strong) NSMutableDictionary *contactsGroupedInSections;

@end

@implementation KBContactsTableViewDataSource

static NSString *cellIdentifier = @"KBContactCell";

#pragma mark - Initialization

- (instancetype)initWithTableView:(UITableView*)tableView configuration:(KBContactsSelectionConfiguration*)configuration
{
    self = [super init];
    if (self) {
        _tableView = tableView;
        _configuration = configuration;
        [_tableView registerNib:[UINib nibWithNibName:_configuration.customContactCellNib?:@"KBContactCell"
                                               bundle:[NSBundle mainBundle]]
         forCellReuseIdentifier:cellIdentifier];
        
        [self initializeArrays];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadContacts];
        });
    }
    return self;
}

- (void)initializeArrays
{
    _unfilteredContacts = [NSArray array];
    _contacts = [NSArray array];
    _selectedContactsRecordIds = [NSMutableArray array];
    _sectionIndexTitles = [NSArray array];
    _contactsGroupedInSections = [NSMutableDictionary dictionary];
}

- (void)loadContacts
{
    NSArray * cached = nil;
    if (self.configuration.restoreCache) {
        cached = self.configuration.restoreCache();
    }
    if (cached) {
        self.unfilteredContacts = self.contacts = cached;
        [self runSearch:self.lastSearch];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (cached) {
            [self.delegate dataSourceRestoredCachedContacts:self];
        } else {
    [self.delegate dataSourceWillLoadContacts:self];
        }
    });
    
    APAddressBook *ab = [[APAddressBook alloc] init];
    ab.fieldsMask = APContactFieldFirstName | APContactFieldLastName | APContactFieldPhonesWithLabels | APContactFieldEmails | APContactFieldRecordID;
    ab.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"firstName" ascending:YES]];
    
    ab.filterBlock = ^BOOL(APContact *contact){
        if (_configuration.skipUnnamedContacts && contact.fullName.length < 1) {
            return NO;
        }
        
        if (_configuration.mode & KBContactsSelectionModeMessages) {
            if (contact.phonesWithLabels.count > 0) {
                return YES;
            }
        }
        if (_configuration.mode & KBContactsSelectionModeEmail) {
            if (contact.emails.count > 0) {
                return YES;
            }
        }
        return NO;
    };
    
    [ab loadContactsOnQueue:dispatch_get_global_queue(0, 0)
                 completion:^(NSArray *contacts, NSError *error) {
        if (contacts) {
            NSArray *filteredContacts = [self filteredDuplicatedContacts:contacts];
             self.unfilteredContacts = filteredContacts;
            self.contacts = filteredContacts;
        }
         [self runSearch:self.lastSearch];
         
         if (self.configuration.storeCache) {
             self.configuration.storeCache(self.unfilteredContacts);
         }
                     
         dispatch_async(dispatch_get_main_queue(), ^{
             if (cached) {
                 [self.delegate dataSourceUpdateCachedContacts:self];
             } else {
        [self.delegate dataSourceDidLoadContacts:self];
             }
         });
    }];
}

//This method filters duplicated contacts by full name and phone.
//Duplicated contacts occur when device synchronizes contacts with more than one cloud: e.g. iCloud and google.
- (NSArray*)filteredDuplicatedContacts:(NSArray*)contacts
{
    NSMutableArray *filteredContacts = [NSMutableArray array];
    
    for (APContact *contact in contacts) {
        if (![self contactsArray:filteredContacts containsContact:contact]) {
            [filteredContacts addObject:contact];
        }
    }
    
    return filteredContacts;
}

- (BOOL)contactsArray:(NSArray*)array containsContact:(APContact*)searchedContact
{
    NSString *searchedContactFullName = [searchedContact fullName];
    
    for (APContact *contact in array) {
        BOOL fullNamesEqual = [[contact fullName] isEqualToString:searchedContactFullName];
        
        if (_configuration.mode & KBContactsSelectionModeMessages) {
            if (contact.phonesWithLabels.count > 0 && searchedContact.phonesWithLabels.count > 0) {
                NSString *searchedContactPhone = ((APPhoneWithLabel*) searchedContact.phonesWithLabels[0]).phone;
                BOOL phonesEqual = [((APPhoneWithLabel*) contact.phonesWithLabels[0]).phone isEqualToString:searchedContactPhone];
                
                if (fullNamesEqual && phonesEqual) {
                    return YES;
                }
            }
        }
        if (_configuration.mode & KBContactsSelectionModeEmail) {
            if (contact.emails.count > 0 && searchedContact.emails.count > 0) {
                NSString *searchedContactEmail = searchedContact.emails[0];
                BOOL emailsEqual = [contact.emails[0] isEqualToString:searchedContactEmail];
                
                if (fullNamesEqual && emailsEqual) {
                    return YES;
                }
            }
        }
    }
    
    return NO;
}

- (void)updateAfterModifyingContacts
{
    [self groupContacts];
    [self prepareInitials];
    
    [_tableView reloadData];
    _tableView.tableHeaderView = nil;
}

- (void)groupContacts
{
    _contactsGroupedInSections = [NSMutableDictionary dictionary];
    
    for (APContact *contact in _contacts) {
        NSString *firstLetter = [contact firstLetterOfFullName];
        NSMutableArray *contactsForFirstLetter = _contactsGroupedInSections[firstLetter] ?: [NSMutableArray array];
        [contactsForFirstLetter addObject:contact];
        _contactsGroupedInSections[firstLetter] = contactsForFirstLetter;
    }
}

- (void)prepareInitials
{
    NSMutableSet *contactsInitialsSet = [NSMutableSet set];
    [_contacts enumerateObjectsUsingBlock:^(APContact *contact, NSUInteger idx, BOOL *stop) {
        [contactsInitialsSet addObject:[contact firstLetterOfFullName]];
    }];
    _sectionIndexTitles = [[contactsInitialsSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(NSString *s1, NSString *s2) {
        return [s1 localizedCaseInsensitiveCompare:s2];
    }];
}

#pragma mark - Public Methods

- (void)runSearch:(NSString*)text
{
    _lastSearch = text;
    
    NSMutableArray * keywords = [text.lowercaseString componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].mutableCopy;
    while ([keywords containsObject:@""]) {
        [keywords removeObject:@""];
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (text.length == 0) {
            _contacts = _unfilteredContacts;
        } else {
            NSMutableArray *filteredContacts = [NSMutableArray array];
            [_unfilteredContacts enumerateObjectsUsingBlock:^(APContact *contact, NSUInteger idx, BOOL *stop) {
                BOOL shouldAdd = YES;
                
                if (self.configuration.searchByKeywords) {
                    NSMutableArray * pendingKeywords = keywords.mutableCopy;
                    NSArray * components = [[contact fullName].lowercaseString componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
                    for (NSString * key in pendingKeywords.copy) {
                        for (NSString * component in components) {
                            if ([component hasPrefix:key]) {
                                [pendingKeywords removeObject:key];
                                break;
                            }
                        }
                    }
                    shouldAdd = pendingKeywords.count == 0;
                } else {
                    shouldAdd = [[contact fullName] rangeOfString:text options:NSCaseInsensitiveSearch].location != NSNotFound;
                }
                if (shouldAdd) {
                    [filteredContacts addObject:contact];
                }
            }];
            _contacts = filteredContacts;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateAfterModifyingContacts];
        });
    });
}

- (void)selectAll
{
    [_selectedContactsRecordIds removeAllObjects];
    for (int section = 0; section < [self.tableView numberOfSections]; section++) {
        for (int row = 0; row < [self.tableView numberOfRowsInSection:section]; row++) {
            NSIndexPath* cellPath = [NSIndexPath indexPathForRow:row inSection:section];
            [self tableView:self.tableView didSelectRowAtIndexPath:cellPath];
        }
    }
}

- (void)removeAll {
    
    [_selectedContactsRecordIds removeAllObjects];
}

- (NSArray*)selectedContacts
{
    NSMutableArray *result = [NSMutableArray array];
    
    [_unfilteredContacts enumerateObjectsUsingBlock:^(APContact *contact, NSUInteger idx, BOOL *stop) {
        if ([_selectedContactsRecordIds containsObject:contact.recordID]) {
            [result addObject:contact];
        }
    }];
    
    return result;
}

- (NSArray*)phonesOfSelectedContacts
{
    NSMutableArray *result = [NSMutableArray array];
    
    [[self selectedContacts] enumerateObjectsUsingBlock:^(APContact *contact, NSUInteger idx, BOOL *stop) {
        if (contact.phonesWithLabels && contact.phonesWithLabels.count > 0) {
            [result addObject:((APPhoneWithLabel*)contact.phonesWithLabels[0]).phone];
        }
    }];
    
    return result;
}

- (NSArray*)emailsOfSelectedContacts
{
    NSMutableArray *result = [NSMutableArray array];
    
    [[self selectedContacts] enumerateObjectsUsingBlock:^(APContact *contact, NSUInteger idx, BOOL *stop) {
        if (contact.emails && contact.emails.count > 0) {
            [result addObject:contact.emails[0]];
        }
    }];
    
    return result;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _sectionIndexTitles.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return _sectionIndexTitles[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *sectionTitle = _sectionIndexTitles[section];
    NSArray *contacts = _contactsGroupedInSections[sectionTitle];
    return contacts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    KBContactCell *cell = [_tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    APContact *contact = [self contactAtIndexPath:indexPath];
    if (contact) {
        cell.labelName.text = [contact fullName];
        
        NSString * typeText = @"";
        NSString * phoneText = nil;
        if (_configuration.mode & KBContactsSelectionModeMessages) {
            if (contact.phonesWithLabels.count > 0) {
                APPhoneWithLabel *phoneWithLabel = contact.phonesWithLabels[0];
                if (phoneWithLabel) {
                    phoneText = phoneWithLabel.phone;
                    typeText = phoneWithLabel.label;
                }
            }
        }
        if (_configuration.mode & KBContactsSelectionModeEmail) {
            if (contact.emails.count > 0) {
                if (!phoneText) {
                    phoneText = contact.emails[0];
                } else {
                    phoneText = [NSString stringWithFormat:@"%@, %@", phoneText, contact.emails[0]];
                }
            }
        }
        cell.labelPhone.text = phoneText;
        cell.labelPhoneType.text = typeText;
        
        cell.buttonSelection.innerCircleFillColor = _configuration.tintColor;
        cell.buttonSelection.selected = [_selectedContactsRecordIds containsObject:contact.recordID];
        
        BOOL enabled = YES;
        if (_configuration.contactEnabledValidation) {
            if (!_configuration.contactEnabledValidation(contact)) {
                enabled = NO;
            }
        }
        cell.labelName.alpha = cell.labelPhone.alpha = (enabled? 1: 0.3);
        cell.buttonSelection.enabled = enabled;
        cell.userInteractionEnabled = enabled;
    }
    
    return cell;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return _sectionIndexTitles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return index;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    KBContactCell *cell = (KBContactCell*)[tableView cellForRowAtIndexPath:indexPath];
    cell.buttonSelection.selected = !cell.buttonSelection.selected;
    
    APContact *contact = [self contactAtIndexPath:indexPath];
    if (contact) {
        BOOL selected = [_selectedContactsRecordIds containsObject:contact.recordID];
        if (selected) {
            [_selectedContactsRecordIds removeObject:contact.recordID];
            if ([_delegate respondsToSelector:@selector(dataSource:didRemoveContact:)]) {
                [_delegate dataSource:self didRemoveContact:contact];
            }
        } else {
            [_selectedContactsRecordIds addObject:contact.recordID];
            if ([_delegate respondsToSelector:@selector(dataSource:didSelectContact:)]) {
                [_delegate dataSource:self didSelectContact:contact];
            }
        }
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    KBContactCell *cell = (KBContactCell*)[tableView cellForRowAtIndexPath:indexPath];
    cell.buttonSelection.highlighted = YES;
}

- (void)tableView:(UITableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    KBContactCell *cell = (KBContactCell*)[tableView cellForRowAtIndexPath:indexPath];
    cell.buttonSelection.highlighted = NO;
}

#pragma mark - Helpers

- (APContact*)contactAtIndexPath:(NSIndexPath*)indexPath
{
    if (indexPath.section < _contactsGroupedInSections.count) {
        NSArray *contactsInSection = _contactsGroupedInSections[_sectionIndexTitles[indexPath.section]];
        if (indexPath.row < contactsInSection.count) {
            return contactsInSection[indexPath.row];
        }
    }
    return nil;
}

@end
