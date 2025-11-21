//
//  ScreenshotWidgetBundle.swift
//  ScreenshotWidget
//
//  Created by saya lee on 11/21/25.
//

import WidgetKit
import SwiftUI

@main
struct ScreenshotWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScreenshotWidget()
        ScreenshotWidgetControl()
        ScreenshotWidgetLiveActivity()
    }
}
