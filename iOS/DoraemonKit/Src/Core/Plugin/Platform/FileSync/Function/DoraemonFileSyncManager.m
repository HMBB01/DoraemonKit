//
//  DoraemonFileSyncManager.m
//  DoraemonKit-DoraemonKit
//
//  Created by didi on 2020/6/10.
//

#import "DoraemonFileSyncManager.h"
#import <GCDWebServer/GCDWebServerRequest.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>
#import <GCDWebServer/GCDWebServerMultiPartFormRequest.h>
#import "DoraemonAppInfoUtil.h"

@interface DoraemonFileSyncManager()

@property (nonatomic, strong) NSFileManager *fm;

@end


@implementation DoraemonFileSyncManager

+ (instancetype)sharedInstance{
    static DoraemonFileSyncManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DoraemonFileSyncManager alloc] init];
    });
    return instance;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _start = NO;
        [self setRouter];
        _fm = [NSFileManager defaultManager];
    }
    return self;
}

- (void)setRouter{
    [self addDefaultHandlerForMethod:@"GET"
                        requestClass:[GCDWebServerRequest class]
                        processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        NSString *html = @"<html><body>请访问 <b><a href=\"https://www.dokit.cn\">www.dokit.cn</a></b> 使用该功能</body></html>";
        return [GCDWebServerDataResponse responseWithHTML:html];
    }];
    
    __weak typeof(self) weakSelf = self;
    [self addHandlerForMethod:@"GET"
                         path:@"/getDeviceInfo"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return  [weakSelf getDeviceInfo];
    }];
    
    [self addHandlerForMethod:@"GET"
                         path:@"/getFileList"
                 requestClass:[GCDWebServerRequest class]
                 processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return [weakSelf getFileList:request];
    }];
    
    [self addHandlerForMethod:@"POST" path:@"/uploadFile" requestClass:[GCDWebServerMultiPartFormRequest class] processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        return [weakSelf uploadFile:(GCDWebServerMultiPartFormRequest *)request];
    }];
}

- (NSString *)getRelativeFilePath:(NSString *)fullPath{
    NSString *rootPath = NSHomeDirectory();
    return [fullPath stringByReplacingOccurrencesOfString:rootPath withString:@""];
}

- (NSDictionary *)getCode:(NSInteger)code data:(NSDictionary *)data{
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    [info setValue:@(code) forKey:@"code"];
    [info setValue:data forKey:@"data"];
    return info;
}

- (void)startServer{
    [self startWithPort:9002 bonjourName:@"Hello DoKit"];
}


#pragma mark -- 服务具体处理
- (GCDWebServerResponse *)getDeviceInfo{
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setValue:[DoraemonAppInfoUtil iphoneName] forKey:@"deviceName"];
    [dic setValue:[DoraemonAppInfoUtil uuid] forKey:@"deviceId"];
    
    NSDictionary *info = [self getCode:200 data:dic];
    GCDWebServerResponse *response = [GCDWebServerDataResponse responseWithJSONObject:info];
    [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
    
    return response;
}

- (GCDWebServerResponse *)getFileList: (GCDWebServerRequest *)request{
    
    NSDictionary *query = request.query;
    NSString *filePath = query[@"filePath"];
    NSString *rootPath = NSHomeDirectory();
    NSString *targetPath = [NSString stringWithFormat:@"%@%@",rootPath,filePath];
    
    NSMutableArray *files = @[].mutableCopy;
       NSError *error = nil;
    NSArray *paths = [_fm contentsOfDirectoryAtPath:targetPath error:&error];
    for (NSString *path in paths) {
        BOOL isDir = false;
        NSString *fullPath = [targetPath stringByAppendingPathComponent:path];
        [_fm fileExistsAtPath:fullPath isDirectory:&isDir];
        
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        dic[@"name"] = path;
        dic[@"filePath"] = [self getRelativeFilePath:fullPath];
        if (isDir) {
            dic[@"fileType"] = @"dir";
        }else{
            dic[@"fileType"] = [path pathExtension];
        }
        [files addObject:dic];
    }
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setValue:filePath forKey:@"filePath"];
    [data setValue:[DoraemonAppInfoUtil uuid] forKey:@"deviceId"];
    [data setValue:files forKey:@"fileList"];
    
    NSDictionary *res = [self getCode:200 data:data];
    
    GCDWebServerResponse *response = [GCDWebServerDataResponse responseWithJSONObject:res];
    [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
    
    return response;
}

- (GCDWebServerResponse*)uploadFile:(GCDWebServerMultiPartFormRequest*)request{
    GCDWebServerMultiPartFile* file = [request firstFileForControlName:@"file"];
    NSString *filePath = [[request firstArgumentForControlName:@"filePath"] string];
    NSString *rootPath = NSHomeDirectory();
    NSString *targetPath = [NSString stringWithFormat:@"%@%@%@",rootPath,filePath,file.fileName];
    NSError* error = nil;
    if (![[NSFileManager defaultManager] moveItemAtPath:file.temporaryPath toPath:targetPath error:&error]) {
        NSLog(@"Failed moving uploaded file to \"%@\"", targetPath);
    }
    
    return [GCDWebServerDataResponse responseWithJSONObject:@{}];;
}

@end
