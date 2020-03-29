


#import "HelperFunc.h"

void runAlert(NSString*title, NSString*message) {
    // NSRunAlertPanel(title, @"%@", message, @"OK", nil, nil);
    NSAlert *showAlert = [[NSAlert alloc] init];
    [showAlert addButtonWithTitle:@"Coninue"];
    [showAlert setMessageText:(message)];
    [showAlert setAlertStyle:(NSAlertStyleInformational)];
    
    
}
