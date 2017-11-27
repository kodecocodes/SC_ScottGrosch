//
//  Copyright (c) 2015 Jan Gorman. All rights reserved.
//

// Taken from https://github.com/grosch/Zoetrope on November 27th, 2017 and updated
// to compile with Swift 4 and Xcode 9 for the raywenderlich.com screencast.

import UIKit
import ImageIO
import MobileCoreServices

public enum ZoetropeError: Error {
    case InvalidData
}

private struct Frame {
    fileprivate let delay: Double
    fileprivate let image: UIImage
}

private struct Zoetrope {

    let posterImage: UIImage?
    let loopCount: Int
    let frameCount: Int

    private let framesForIndexes: [Int: Frame]

    init(data: Data) throws {
        guard let imageSource = CGImageSourceCreateWithData(data as NSData, nil),
            let imageType = CGImageSourceGetType(imageSource),
            UTTypeConformsTo(imageType, kUTTypeGIF) else {
                throw ZoetropeError.InvalidData
        }
        loopCount = try Zoetrope.loopCountFromImageSource(imageSource)
        framesForIndexes = Zoetrope.frames(imageSource)
        frameCount = framesForIndexes.count
        guard !framesForIndexes.isEmpty else {
            throw ZoetropeError.InvalidData
        }
        posterImage = framesForIndexes[0]?.image
    }

    func imageAtIndex(_ index: Int) -> UIImage? {
        return framesForIndexes[index]?.image
    }

    func delayAtIndex(_ index: Int) -> Double? {
        return framesForIndexes[index]?.delay
    }

}

private extension Zoetrope {
    
    static func loopCountFromImageSource(_ imageSource: CGImageSource) throws -> Int {
        guard let imageProperties: NSDictionary = CGImageSourceCopyProperties(imageSource, nil),
            let gifProperties = imageProperties[kCGImagePropertyGIFDictionary as String] as? NSDictionary,
            let loopCount = gifProperties[kCGImagePropertyGIFLoopCount as String] as? Int else {
                throw ZoetropeError.InvalidData
        }
        return loopCount
    }
    
    static func frames(_ imageSource: CGImageSource) -> [Int: Frame] {
        var frames = [Int: Frame]()
        for i in 0..<CGImageSourceGetCount(imageSource) {
            if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil),
                let frameProperties: NSDictionary = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil),
                let gifFrameProperties = frameProperties[kCGImagePropertyGIFDictionary as String] as? NSDictionary {
                let previous: Double! = i == 0 ? 0.1 : frames[i - 1]?.delay
                let delay = Zoetrope.delayTimefromProperties(gifFrameProperties, previousFrameDelay: previous)
                frames[i] = Frame(delay: delay, image: UIImage(cgImage: cgImage))
            }
        }
        return frames
    }
    
    static func delayTimefromProperties(_ properties: NSDictionary, previousFrameDelay: Double) -> Double {
        var delayTime: Double! = (properties[kCGImagePropertyGIFUnclampedDelayTime as String]
            ?? properties[kCGImagePropertyGIFDelayTime as String]) as? Double
        if delayTime == nil {
            delayTime = previousFrameDelay
        }
        if delayTime < (0.02 - Double.ulpOfOne) {
            delayTime = 0.02
        }
        return delayTime
    }
    
}

/**
 `ZoetropeImageView` is a `UIImageView` subclass for displaying animated gifs.
 
 Use like any other `UIImageView` and call `setData:` to pass in the `Data`
 that represents your animated gif.
 */
public class ZoetropeImageView: UIImageView {
    
    private var currentFrameIndex = 0
    private var loopCountDown = 0
    private var accumulator = 0.0
    private var needsDisplayWhenImageBecomesAvailable = false
    private var currentFrame: UIImage!
    
    public override var image: UIImage? {
        get {
            return animatedImage != nil ? currentFrame : super.image
        }
        set {
            super.image = image
        }
    }

    private lazy var displayLink: CADisplayLink = { [unowned self] in
        let displayLink = CADisplayLink(target: self, selector: #selector(displayDidRefresh(displayLink:)))
        displayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
        return displayLink
        }()

    private var animatedImage: Zoetrope! {
        didSet {
            image = nil
            isHighlighted = false
            invalidateIntrinsicContentSize()
            
            currentFrame = animatedImage.posterImage
            currentFrameIndex = 0
            loopCountDown = animatedImage.loopCount > 0 ? animatedImage.loopCount : NSIntegerMax

            if shouldAnimate {
                startAnimating()
            }

            layer.setNeedsDisplay()
        }
    }

    /**
     Call setData with the `Data` representation of your gif after adding it to your view.
     
     - Parameter data:   The `Nata` representation of your gif
     - Throws: `ZoetropeError.InvalidData` if the `data` parameter does not contain valid gif data.
     */
    public func setData(_ data: Data) throws {
        animatedImage = try Zoetrope(data: data)
    }

    private var shouldAnimate: Bool {
        return animatedImage != nil && superview != nil
    }
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if shouldAnimate {
            startAnimating()
        } else {
            stopAnimating()
        }
    }
    
    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if shouldAnimate {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    public override var intrinsicContentSize: CGSize {
        guard let _ = animatedImage, let image = image else {
            return super.intrinsicContentSize
        }
        return image.size
    }
    
    public override func startAnimating() {
        if animatedImage != nil {
            displayLink.isPaused = false
        } else {
            super.startAnimating()
        }
    }
    
    public override func stopAnimating() {
        if animatedImage != nil {
            displayLink.isPaused = true
        } else {
            super.stopAnimating()
        }
    }

    public override var isAnimating: Bool {
        guard animatedImage != nil && !displayLink.isPaused else {
            return super.isAnimating
        }

        return true
    }

    
    @objc func displayDidRefresh(displayLink: CADisplayLink) {
        if let image = animatedImage.imageAtIndex(currentFrameIndex),
            let delayTime = animatedImage.delayAtIndex(currentFrameIndex) {
            currentFrame = image
            if needsDisplayWhenImageBecomesAvailable {
                layer.setNeedsDisplay()
                needsDisplayWhenImageBecomesAvailable = false
            }

            accumulator += displayLink.duration
            
            while accumulator >= delayTime {
                accumulator -= delayTime
                currentFrameIndex += 1
                if currentFrameIndex >= animatedImage.frameCount {
                    loopCountDown -= 1
                    guard loopCountDown > 0 else {
                        stopAnimating()
                        return
                    }
                    currentFrameIndex = 0
                }
                needsDisplayWhenImageBecomesAvailable = true
            }
            
        }
    }

    public override func display(_ layer: CALayer) {
        guard let image = image else {
            return
        }
        layer.contents = image.cgImage
    }
    
    deinit {
        displayLink.invalidate()
    }

}
