
//
//  Created by Mike Griebling on 2022-12-31.
//  Translated from an Objective-C implementation by Kostub Deshmukh.
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

import Foundation

public class MTFontManager {
    
    static public private(set) var manager: MTFontManager = {
        MTFontManager()
    }()
    
    let kDefaultFontSize = CGFloat(20)
    
    static var fontManager : MTFontManager {
        return manager
    }

    public init() { }

    @RWLocked
    var nameToFontMap = [String: MTFont]()

    /// Returns nil for a name with no font in the bundle (this fork ships
    /// Latin Modern Math only), instead of trapping inside MTFont's loader.
    public func font(withName name:String, size:CGFloat) -> MTFont? {
        guard MTFont.fontBundle.path(forResource: name, ofType: "otf") != nil else { return nil }
        var f = self.nameToFontMap[name]
        if f == nil {
            f = MTFont(fontWithName: name, size: size)
            self.nameToFontMap[name] = f
        }
        
        if f!.fontSize == size { return f }
        else { return f!.copy(withSize: size) }
    }
    
    public func latinModernFont(withSize size:CGFloat) -> MTFont? {
        MTFontManager.fontManager.font(withName: "latinmodern-math", size: size)
    }
    
    public var defaultFont: MTFont? {
        MTFontManager.fontManager.latinModernFont(withSize: kDefaultFontSize)
    }


}
