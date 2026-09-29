import Foundation
import UIKit

enum Log {
     static func d (
        _ message:String,
        _ data: @autoclosure () -> Any?,
        file: String = #file,
        line: Int = #line
    ) {
//             let resolvedData = data()
        
     
        print("\n[\(file):\(line)]",message)
      
    }
    
    
    private static func extractFileName(from path: String) -> String {
        return path.components(separatedBy: "/").last ?? ""
    }
    
}
