//
//  MUMusicManager.m
//  Songs
//
//  Created by Steven Degutis on 3/25/13.
//  Copyright (c) 2013 Steven Degutis. All rights reserved.
//

#import "SDUserDataManager.h"

#import <AVFoundation/AVFoundation.h>

#import "MAKVONotificationCenter.h"

@interface SDUserDataManager ()

@property BOOL canSave;

@property SDPlaylistCollection* rootNode;

@property SDMasterPlaylist* masterPlaylist;
@property SDPlaylistCollection* userPlaylistsCollection;

@end

@implementation SDUserDataManager

+ (SDUserDataManager*) sharedMusicManager {
    static SDUserDataManager* sharedMusicManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMusicManager = [[SDUserDataManager alloc] init];
    });
    return sharedMusicManager;
}

- (id) init {
    if (self = [super init]) {
        self.rootNode = [[SDPlaylistCollection alloc] init];
        
        [[MAKVONotificationCenter defaultCenter] observeTarget:self
                                                       keyPath:@"userPlaylistsCollection.playlists"
                                                       options:0
                                                         block:^(MAKVONotification *notification) {
                                                             [SDUserDataManager userDataChanged];
                                                         }];
    }
    return self;
}

- (void) loadUserData {
//    NSLog(@"loading");
    
    NSData* masterPlaylistData = [[NSUserDefaults standardUserDefaults] dataForKey:@"masterPlaylist"];
    NSData* userPlaylistsData = [[NSUserDefaults standardUserDefaults] dataForKey:@"userPlaylists"];
    
    if (masterPlaylistData)
        self.masterPlaylist = [NSKeyedUnarchiver unarchiveObjectWithData:masterPlaylistData];
    else
        self.masterPlaylist = [[SDMasterPlaylist alloc] init];
    
    [self.rootNode.playlists addObject:self.masterPlaylist];
    
    self.userPlaylistsCollection = [[SDPlaylistCollection alloc] init];
    [self.rootNode.playlists addObject:self.userPlaylistsCollection];
    
    if (userPlaylistsData) {
        NSArray* playlists = [NSKeyedUnarchiver unarchiveObjectWithData:userPlaylistsData];
        [self.userPlaylistsCollection.playlists addObjectsFromArray:playlists];
    }
    
    self.canSave = YES;
}

- (void) saveUserData {
    if (!self.canSave)
        return;
    
//    NSLog(@"saving");
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:self.masterPlaylist] forKey:@"masterPlaylist"];
    [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:[self userPlaylists]] forKey:@"userPlaylists"];
}

- (void) importSongsUnderURLs:(NSArray*)urls {
    [SDUserDataManager filterOnlyPlayableURLs:urls completionHandler:^(NSArray *urls) {
        [self.masterPlaylist addSongsWithURLs:urls];
    }];
}

+ (void) filterOnlyPlayableURLs:(NSArray*)urls completionHandler:(void(^)(NSArray* urls))handler {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray* list = [NSMutableArray array];
        
        NSFileManager* fileManager = [[NSFileManager alloc] init];
        
        for (NSURL* url in urls) {
            BOOL isDir;
            BOOL exists = [fileManager fileExistsAtPath:[url path] isDirectory:&isDir];
            if (!exists)
                continue;
            
            if (isDir) {
                NSDirectoryEnumerator* dirEnum = [fileManager enumeratorAtURL:url
                                                   includingPropertiesForKeys:@[]
                                                                      options:NSDirectoryEnumerationSkipsPackageDescendants & NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:^BOOL(NSURL *url, NSError *error) {
                                                                     NSLog(@"error for [%@]! %@", url, error);
                                                                     return YES;
                                                                 }];
                
                for (NSURL* file in dirEnum) {
                    AVURLAsset* asset = [AVURLAsset assetWithURL:file];
                    if ([asset isPlayable]) {
                        [list addObject:file];
                    }
                }
            }
            else {
                AVURLAsset* asset = [AVURLAsset assetWithURL:url];
                if ([asset isPlayable]) {
                    [list addObject:url];
                }
            }
        }
        
        NSArray* urls = [list valueForKeyPath:@"fileReferenceURL"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(urls);
        });
    });
}

+ (void) userDataChanged {
    [[SDUserDataManager sharedMusicManager] saveUserData];
}

- (NSArray*) allSongs {
    return [self.masterPlaylist songs];
}

- (NSArray*) userPlaylists {
    return [self.userPlaylistsCollection playlists];
}

@end
