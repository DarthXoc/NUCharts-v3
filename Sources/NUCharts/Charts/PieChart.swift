//
//  PieChart.swift
//  NUCharts
//
//  Created by Jason Cox on 7/8/20.
//  Copyright © 2020 Jason Cox. All rights reserved.
//

import UIKit

public protocol PieChartDataSource: class {
    /// Asks the delegate for the number of items that will be drawn on the chart
    func numberOfItems(in pieChart: PieChart) -> Int;
    
    /// Asks the data source what the background color of the slice should be
    func pieChart(_ pieChart: PieChart, backgroundColorForItemAt index: Int, selected boolSelected: Bool) -> UIColor;
    
    /// Asks the data source what the fill color of the slice should be
    func pieChart(_ pieChart: PieChart, fillColorForItemAt index: Int, selected boolSelected: Bool) -> UIColor;
    
    /// Asks the data source what percentage of the slice should be filled
    func pieChart(_ pieChart: PieChart, percentFillForItemAt index: Int) -> CGFloat;
    
    /// Asks the data source what the title for the tooltip should be
    func pieChart(_ pieChart: PieChart, tooltipTitleForItemAt index: Int) -> String;
    
    /// Asks the data source what the value for the tooltip should be
    func pieChart(_ pieChart: PieChart, tooltipValueForItemAt index: Int) -> String;
    
    /// Asks the data source for the value at the specified index
    func pieChart(_ pieChart: PieChart, valueForItemAt index: Int) -> Double;
}

public protocol PieChartDelegate: class {
    /// Informs the delegate the the item at the specified index was selected
    func pieChart(_ pieChart: PieChart, didSelectItemAt index: Int?);
}

public extension PieChartDataSource {
    func pieChart(_ pieChart: PieChart, backgroundColorForItemAt index: Int, selected boolSelected: Bool) -> UIColor {
        return .opaqueSeparator;
    };
    
    func pieChart(_ pieChart: PieChart, fillColorForItemAt index: Int, selected boolSelected: Bool) -> UIColor {
        // Calculate the number of items in the array of values
        let intNumberOfItems: Int = self.numberOfItems(in: pieChart);
        
        // Calculate the color adjustment step
        let floatAdjustment: CGFloat = (CGFloat(index) / CGFloat(intNumberOfItems)) / 2;
        
        // The original color
        let colorOriginal: CIColor = CIColor(color: !boolSelected ? pieChart.settings.slice.color! : pieChart.settings.slice.selectedColor!);
        
        // Calculate the new color
        let colorNew: CIColor = CIColor(red: colorOriginal.red + floatAdjustment,
                                      green: colorOriginal.green + floatAdjustment,
                                      blue: colorOriginal.blue + floatAdjustment,
                                      alpha: colorOriginal.alpha);
        
        // Convert the new color from CIColor to UIColor
        let color: UIColor = UIColor(ciColor: colorNew);
        
        return color;
    }
    
    func pieChart(_ pieChart: PieChart, percentFillForItemAt index: Int) -> CGFloat {
        return 1.0;
    }
    
    func pieChart(_ pieChart: PieChart, tooltipTitleForItemAt index: Int) -> String {
        return "Index \(index)";
    }
    
    func pieChart(_ pieChart: PieChart, tooltipValueForItemAt index: Int) -> String {
        return String(self.pieChart(pieChart, valueForItemAt: index));
    }
}

public extension PieChartDelegate {
    func pieChart(_ pieChart: PieChart, didSelectItemAt index: Int?) {
    };
}

public class PieChart: UIView, UIGestureRecognizerDelegate {
    // Setup the data source
    public weak var dataSource: PieChartDataSource?;
    
    // Setup the delegate
    public weak var delegate: PieChartDelegate?;
    
    // MARK: - Structures
    
    /// Properties used to configure a chart's settings
    public struct Settings {
        /// The chart's background color
        public var backgroundColor: UIColor = .secondarySystemBackground;
                
        /// The chart's border
        public var border: ChartCore.Border = ChartCore.Border();
        
        /// The chart's corner radius
        public var cornerRadius: CGFloat = 8.0;
        
        /// The size of the center 'donut' hole, expressed at a percent of the pie's radius
        public var donutHole: CGFloat = .zero;
        
        /// Padding applied to the left, top, right and bottom edges of the chart
        public var padding: UIEdgeInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0);
        
        /// The type of pie chart that will be drawn
        public var pieType: ChartCore.PieType = .full;
        
        /// Properties used in the drawing of slices in a pie chart
        public var slice: Slice = Slice();
        
        /// Properties used in the drawing of tooltips
        public var tooltip: ChartCore.Tooltip = ChartCore.Tooltip();
    }
    
    /// Properties used in the drawing of slices in a pie chart
    public struct Slice {
        /// The slice's border
        public var border: ChartCore.Border? = ChartCore.Border(color: nil, width: 1.0);
        
        /// The color used by slices; this color will be stepped down incrimentally when the data source method pieChart(colorForItemAt:selected:) has not been implemented
        public var color: UIColor?;
        
        /// The color used by selected slices; this color will be stepped down incrimentally when the data source method pieChart(colorForItemAt:selected:) has not been implemented
        public var selectedColor: UIColor?;
    }
    
    // MARK: - Variables
    
    /// An array of paths for all drawn slices
    private var arraySliceBounds: [ChartCore.SliceBounds] = [];
    
    /// The maximum value that will be displayed on the chart
    private var doubleTotalValue: Double = .zero;
    
    /// The currently selected index
    private var intIndexSelected: Int?;
    
    /// The current location and dimensions of the displayed tooltip
    private var rectTooltip: CGRect?;
    
    /// The chart's settings
    public var settings: Settings = Settings();
    
    /// Returns the currently selected index
    public var selectedIndex: Int? {
        get {
            self.intIndexSelected;
        }
        set {
            intIndexSelected = newValue ?? nil;
        }
    }
    
    /// The object in which the chart will be drawn
    private var viewChart: UIView?;
    
    // MARK: - General
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        // Check to see if the userInterfaceStyle or size class / orientation changed
        if (traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle || traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass || traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass) {
            // Draw the chart
            self.draw(resetSelectedIndex: false, resetTooltip: false);
        }
    }
    
    // MARK: - Calculations
    
    /// Calculate the percent of the total pie for the given index
    private func calculatePercent(forItemAt index: Int) -> CGFloat {
        // Calculate the total value of all items in the array of values
        let doubleTotal: Double = doubleTotalValue;
        
        // Retreive the value for the given index
        let doubleCurrent: Double = dataSource!.pieChart(self, valueForItemAt: index);
        
        return CGFloat(doubleCurrent / doubleTotal);
    }
        
    // MARK: - Chart
    
    // Draws the chart
    public func draw(resetSelectedIndex boolResetSelectedIndex: Bool = true, resetTooltip boolResetTooltip: Bool = true) {
        // Check to see if the selected index should be reset
        if (boolResetSelectedIndex) {
            // Reset the selected index
            intIndexSelected = nil;
        }
        
        // Check to see if the tooltip's location should be reset
        if (boolResetTooltip) {
            // Reset the location of the tooltip
            rectTooltip = nil;
        }
        
        // Check to see the pie's color has been selected was specified
        if (self.settings.slice.color == nil) {
            // Set the pie's positive color to the chart's tint color
            self.settings.slice.color = self.tintColor;
        }
        
        // Check to see the pie's selected color when it has been selected was specified
        if (self.settings.slice.selectedColor == nil) {
            // Set the pie's positive color when it has been selected to the chart's tint color blended with black
            self.settings.slice.selectedColor = ChartCore.blendColors(colors: [self.tintColor, .black]);
        }
        
        // Remove the background color
        self.backgroundColor = .clear;
        
        // Clip the subviews
        self.clipsToBounds = true;
        
        // Remove all subviews
        self.subviews.forEach({ $0.removeFromSuperview(); });
        
        // Reset the total value prior to calculating it
        doubleTotalValue = .zero;
        
        // Iterate through each value in the chart
        for index: Int in 0 ..< dataSource!.numberOfItems(in: self) {
            // Calculate the total value
            doubleTotalValue += dataSource!.pieChart(self, valueForItemAt: index);
        }
        
        // Configure the UIView
        viewChart = UIView();
        viewChart!.translatesAutoresizingMaskIntoConstraints = false;
        
        // Apply the settings
        self.backgroundColor = self.settings.backgroundColor;
        self.layer.cornerRadius = self.settings.cornerRadius;
        self.layer.borderColor = self.settings.border.color?.cgColor ?? UIColor.clear.cgColor;
        self.layer.borderWidth = self.settings.border.width;
        
        // Add the UIView to the UIView
        self.addSubview(viewChart!);
        
        // Add any required layout constraints
        self.addConstraint(NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: viewChart, attribute: .leading, multiplier: 1.0, constant: -self.settings.padding.left));
        self.addConstraint(NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: viewChart, attribute: .top, multiplier: 1.0, constant: -self.settings.padding.top));
        self.addConstraint(NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: viewChart, attribute: .trailing, multiplier: 1.0, constant: self.settings.padding.right));
        self.addConstraint(NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: viewChart, attribute: .bottom, multiplier: 1.0, constant: self.settings.padding.bottom));
        
        // Tell the view to layout if needed
        self.layoutIfNeeded();
        
        // Draw the pie
        self.drawPie(self.settings.pieType, in: viewChart);
        
        // Add a gesture recognizer to the collection view
        let tapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognizer_Tap(sender:)));
        tapGestureRecognizer.delegate = self;
        self.addGestureRecognizer(tapGestureRecognizer);
    }
    
    // MARK: - Drawing
    
    /// Draws the pie chart
    private func drawPie(_ pieType: ChartCore.PieType, in view: UIView?) {
        // Reset the array of slice bounds
        arraySliceBounds = [];
        
        // Remove all sublayers
        view?.layer.sublayers?.forEach({ $0.removeFromSuperlayer() });
        
        // Determine the starting angle
        var floatAngle: CGFloat = pieType == .full ? 270 : 180;
        
        //Calculate the radius
        var floatRadius: CGFloat {
            // Check to see what pie type is being requesting and if we should calculate the radius based on the view's height or width
            if (pieType == .full && (view!.frame.size.height / 2) < (view!.frame.size.width / 2)) {
                return (view!.frame.size.height / 2);
            } else if (pieType == .full && (view!.frame.size.height / 2) > (view!.frame.size.width / 2)) {
                return (view!.frame.size.width / 2);
            } else if (pieType == .half && (view!.frame.size.width / 2) < view!.frame.size.height) {
                return (view!.frame.size.width / 2);
            } else if (pieType == .half && (view!.frame.size.width / 2) > view!.frame.size.height) {
                return view!.frame.size.height;
            }
            
            return .zero;
        }
        
        // Calculate the location of the center point
        let pointCenter: CGPoint = CGPoint(x: view!.frame.size.width / 2,
                                           y: pieType == .full ? view!.frame.size.height / 2 : view!.frame.size.height);
        
        // Check to see if we should draw a full pie chart or a placeholder pie chart
        if (dataSource!.numberOfItems(in: self) > 0) {
            // Iterate through each object in the array of values
            for intIndex: Int in 0 ..< dataSource!.numberOfItems(in: self) {
                // Calculate the percent of the pie that this slice will occupy
                let floatPercent: CGFloat = self.calculatePercent(forItemAt: intIndex);
                
                // Calculate the percent of the slice that will be filled
                let floatPercentFill: CGFloat = self.calculatePercent(forItemAt: intIndex) * dataSource!.pieChart(self, percentFillForItemAt: intIndex);
                
                // Calculate the end angle
                let floatAngleEnd: CGFloat = floatAngle + ((pieType == .full ? 360 : 180) * floatPercent);
                
                // Calculate the end angle for the slice's fill
                let floatAngleEndFill: CGFloat = floatAngle + ((pieType == .full ? 360 : 180) * floatPercentFill);
                
                // Draw the slice
                arraySliceBounds.append(ChartCore.drawSlice(from: pointCenter,
                                                            radius: floatRadius,
                                                            donutRadius: floatRadius * self.settings.donutHole,
                                                            angleStart: floatAngle,
                                                            angleEnd: floatAngleEnd,
                                                            borderColor: self.settings.slice.border?.color,
                                                            borderWidth: self.settings.slice.border?.width,
                                                            fillColor: dataSource!.pieChart(self, backgroundColorForItemAt: intIndex, selected: intIndex == intIndexSelected),
                                                            for: pieType,
                                                            in: view));
                
                // Draw the slice's fill
                ChartCore.drawSlice(from: pointCenter,
                                    radius: floatRadius,
                                    donutRadius: floatRadius * self.settings.donutHole,
                                    angleStart: floatAngle,
                                    angleEnd: floatAngleEndFill,
                                    borderColor: self.settings.slice.border?.color,
                                    borderWidth: self.settings.slice.border?.width,
                                    fillColor: dataSource!.pieChart(self, fillColorForItemAt: intIndex, selected: intIndex == intIndexSelected),
                                    for: pieType,
                                    in: view);
                
                // Update the current angle
                floatAngle = floatAngleEnd;
            }
        } else {
            // Calculate the percent of the pie that this slice will occupy
            let floatPercent: CGFloat = 1.0;
            
            // Calculate the end angle
            let floatAngleEnd: CGFloat = floatAngle + ((pieType == .full ? 360 : 180) * floatPercent);
            
            // Draw the slice
            arraySliceBounds.append(ChartCore.drawSlice(from: pointCenter,
                                                        radius: floatRadius,
                                                        donutRadius: floatRadius * self.settings.donutHole,
                                                        angleStart: floatAngle,
                                                        angleEnd: floatAngleEnd,
                                                        borderColor: self.settings.slice.border?.color,
                                                        borderWidth: self.settings.slice.border?.width,
                                                        fillColor: dataSource!.pieChart(self, backgroundColorForItemAt: 0, selected: false),
                                                        for: pieType,
                                                        in: view));
        }
        
        // Draw the tooltip
        self.drawTooltip();
    }
    
    /// Draws the tooltip if the index path has been selected
    private func drawTooltip() {
        // Check to see if the selected index path is the current index path
        if (intIndexSelected != nil) {
            // Calculate the center point
            let pointSliceCenter: CGPoint = arraySliceBounds[intIndexSelected!].centerPoint;
            
            // Setup an array to house tooltip direction attributes
            var arrayTooltipDirection: [ChartCore.TooltipDirection] = [];
            
            // Check to see what direction the tooltip should open
            if (pointSliceCenter.y > (viewChart!.frame.size.height / 2)) {
                // Draw the tooltip upwards
                arrayTooltipDirection.append(.up);
            } else {
                // Draw the tooltip downwards
                arrayTooltipDirection.append(.down);
            }
            
            // Draw the tooltip
            var rectTooltipLocal: CGRect? = ChartCore.drawTooltip(from: pointSliceCenter,
                                                                  direction: arrayTooltipDirection,
                                                                  title: dataSource!.pieChart(self, tooltipTitleForItemAt: intIndexSelected!),
                                                                  value: dataSource!.pieChart(self, tooltipValueForItemAt: intIndexSelected!),
                                                                  settings: self.settings.tooltip,
                                                                  in: nil);
            
            // Check to see if the tooltip will be drawn off of the left or right side of the screen
            if ((rectTooltipLocal?.origin.x ?? .zero) <= .zero) {
                // Draw the tooltip to the right
                arrayTooltipDirection.append(.right);
            } else if (((rectTooltipLocal?.origin.x ?? .zero) + (rectTooltipLocal?.size.width ?? .zero)) > (viewChart?.frame.size.width ?? .zero)) {
                // Draw the tooltip to the left
                arrayTooltipDirection.append(.left);
            }
            
            // Draw the tooltip
            rectTooltipLocal = ChartCore.drawTooltip(from: pointSliceCenter,
                                                     direction: arrayTooltipDirection,
                                                     title: dataSource!.pieChart(self, tooltipTitleForItemAt: intIndexSelected!),
                                                     value: dataSource!.pieChart(self, tooltipValueForItemAt: intIndexSelected!),
                                                     settings: self.settings.tooltip,
                                                     in: viewChart);
            
            // Save the location of the tooltip to a local variable
            rectTooltip = rectTooltipLocal;
        }
    }
    
    // MARK: - UITapGestureRecognizer
    
    @objc private func tapGestureRecognizer_Tap(sender: UITapGestureRecognizer) {
        // Retreive the touch point
        let pointTouch: CGPoint = sender.location(in: viewChart);
        
        // Record the previously selected index path
        var intIndex: Int?;
        
        // Check to see if the touch event is contained within rectTooltip
        if (rectTooltip?.contains(pointTouch) ?? false) {
            // Inform the delegate that the tooltip was tapped
            delegate?.pieChart(self, didSelectItemAt: intIndexSelected);
            
            return;
        } else {
            // Iterate through each path in the array of paths
            for index: Int in 0 ..< arraySliceBounds.count {
                // Check to see if the path contains the touch point
                if (arraySliceBounds[index].path.contains(pointTouch)) {
                    // Check to see if the current index path is the same as the selected index path
                    // - Additionally, check to see if the data soure has data
                    if (index == intIndexSelected || dataSource!.numberOfItems(in: self) == 0) {
                        // Reset the selected indexPath
                        intIndex = nil;
                    } else {
                        // Set the selected indexPath
                        intIndex = index;
                    }
                }
            }
        }
        
        // Update the selected index
        intIndexSelected = intIndex;
        
        // Check to see if intIndexSelected is nil
        if (intIndexSelected == nil) {
            // Reset the location of the tooltip
            rectTooltip = nil;
        }
        
        // Draw the pie
        self.drawPie(self.settings.pieType, in: viewChart);
    }
}
