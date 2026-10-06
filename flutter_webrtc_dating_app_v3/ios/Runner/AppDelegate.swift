import CoreImage
import CoreVideo
import Flutter
import Metal
import UIKit
import WebRTC

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let videoBeauty = VideoBeautyChannel()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "VideoBeautyChannel") {
      videoBeauty.register(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// 'video_beauty' channel (lib/services/call/beauty_filter.dart). Attaches one
/// BeautyVideoProcessor per local video track. Main thread only.
///
/// flutter_webrtc's headers are not imported (its umbrella module pulls in C++
/// headers), so its LocalVideoTrack is reached through the ObjC runtime.
final class VideoBeautyChannel {
  private var channel: FlutterMethodChannel?
  private var attached: [String: (track: NSObject, processor: BeautyVideoProcessor)] = [:]

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "video_beauty", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      let trackId = args?["trackId"] as? String
      switch call.method {
      case "setBeauty":
        let level = (args?["level"] as? NSNumber)?.floatValue ?? 0
        guard let trackId = trackId else {
          result(false)
          return
        }
        result(self.setBeauty(trackId: trackId, level: level))
      case "clear":
        if let trackId = trackId { self.clear(trackId: trackId) }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  private func setBeauty(trackId: String, level: Float) -> Bool {
    if level <= 0 {
      clear(trackId: trackId)
      return true
    }
    if let entry = attached[trackId] {
      entry.processor.level = level
      return true
    }
    guard let track = Self.localVideoTrack(trackId) else { return false }
    let processor = BeautyVideoProcessor()
    processor.level = level
    Self.call(track, "addProcessing:", processor)
    attached[trackId] = (track, processor)
    return true
  }

  private func clear(trackId: String) {
    guard let entry = attached.removeValue(forKey: trackId) else { return }
    Self.call(entry.track, "removeProcessing:", entry.processor)
  }

  private typealias ClassGetter = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
  private typealias ObjectSetter = @convention(c) (AnyObject, Selector, AnyObject) -> Void

  /// [FlutterWebRTCPlugin sharedSingleton].localTracks[trackId], if it is a
  /// LocalVideoTrack (camera tracks carry a VideoProcessingAdapter).
  private static func localVideoTrack(_ trackId: String) -> NSObject? {
    guard let cls: AnyClass = NSClassFromString("FlutterWebRTCPlugin") else { return nil }
    let singletonSel = NSSelectorFromString("sharedSingleton")
    guard let method = class_getClassMethod(cls, singletonSel) else { return nil }
    let getter = unsafeBitCast(method_getImplementation(method), to: ClassGetter.self)
    guard let plugin = getter(cls, singletonSel)?.takeUnretainedValue() as? NSObject,
      let tracks = plugin.value(forKey: "localTracks") as? NSDictionary,
      let track = tracks[trackId] as? NSObject,
      track.responds(to: NSSelectorFromString("addProcessing:"))
    else { return nil }
    return track
  }

  private static func call(_ target: NSObject, _ selectorName: String, _ arg: AnyObject) {
    let sel = NSSelectorFromString(selectorName)
    guard target.responds(to: sel) else { return }
    let setter = unsafeBitCast(target.method(for: sel), to: ObjectSetter.self)
    setter(target, sel, arg)
  }
}

/// Skin smoothing for outgoing camera frames, called by flutter_webrtc's
/// VideoProcessingAdapter (ExternalVideoProcessingDelegate's -onFrame:) on the
/// capture queue while it holds its lock.
///
/// Blur, then blend it back only where the image is flat: an edge mask keeps
/// eyes, brows, lips and hair sharp.
final class BeautyVideoProcessor: NSObject {
  private static let context: CIContext = {
    let options: [CIContextOption: Any] = [.cacheIntermediates: false]
    if let device = MTLCreateSystemDefaultDevice() {
      return CIContext(mtlDevice: device, options: options)
    }
    return CIContext(options: options)
  }()

  private let levelLock = NSLock()
  private var storedLevel: Float = 0

  var level: Float {
    get {
      levelLock.lock()
      defer { levelLock.unlock() }
      return storedLevel
    }
    set {
      levelLock.lock()
      storedLevel = min(max(newValue, 0), 1)
      levelLock.unlock()
    }
  }

  // Capture queue only.
  private var pool: CVPixelBufferPool?
  private var poolWidth = 0
  private var poolHeight = 0
  private var poolFormat: OSType = 0

  private static let supportedFormats: Set<OSType> = [
    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
    kCVPixelFormatType_32BGRA,
  ]

  @objc(onFrame:)
  func onFrame(_ frame: RTCVideoFrame) -> RTCVideoFrame {
    let strength = level
    guard strength > 0,
      let rtcBuffer = frame.buffer as? RTCCVPixelBuffer,
      !rtcBuffer.requiresCropping()
    else { return frame }

    let input: CVPixelBuffer = rtcBuffer.pixelBuffer
    let format = CVPixelBufferGetPixelFormatType(input)
    let width = CVPixelBufferGetWidth(input)
    let height = CVPixelBufferGetHeight(input)
    guard Self.supportedFormats.contains(format), width > 0, height > 0,
      width * height <= 1920 * 1080,
      let output = makeOutputBuffer(width: width, height: height, format: format)
    else { return frame }

    let image = CIImage(cvPixelBuffer: input)
    let extent = image.extent
    let sizeScale = max(Double(width) / 640.0, 0.5)
    let s = Double(strength)

    let blurred = image.clampedToExtent()
      .applyingGaussianBlur(sigma: (1.5 + 3.5 * s) * sizeScale)
      .cropped(to: extent)

    // Mask = s on flat areas, falling to 0 on edges.
    let gain = 4.0 * s
    let lumaRow = CIVector(x: CGFloat(-gain * 0.30), y: CGFloat(-gain * 0.59), z: CGFloat(-gain * 0.11), w: 0)
    let maxMix = CGFloat(0.9 * s)
    let mask = image
      .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 6.0])
      .clampedToExtent()
      .applyingGaussianBlur(sigma: 1.5 * sizeScale)
      .applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": lumaRow,
        "inputGVector": lumaRow,
        "inputBVector": lumaRow,
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputBiasVector": CIVector(x: maxMix, y: maxMix, z: maxMix, w: 1),
      ])
      .applyingFilter("CIColorClamp")
      .cropped(to: extent)

    let smoothed = blurred
      .applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: image,
        kCIInputMaskImageKey: mask,
      ])
      .applyingFilter("CIColorControls", parameters: [
        kCIInputBrightnessKey: 0.02 * s,
        kCIInputSaturationKey: 1.0,
        kCIInputContrastKey: 1.0,
      ])
      .cropped(to: extent)

    // Same colour tags as the camera buffer so Core Image writes it back the
    // way it was read.
    CVBufferPropagateAttachments(input, output)
    Self.context.render(smoothed, to: output)

    return RTCVideoFrame(
      buffer: RTCCVPixelBuffer(pixelBuffer: output),
      rotation: frame.rotation,
      timeStampNs: frame.timeStampNs)
  }

  private func makeOutputBuffer(width: Int, height: Int, format: OSType) -> CVPixelBuffer? {
    if pool == nil || width != poolWidth || height != poolHeight || format != poolFormat {
      let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: format,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        kCVPixelBufferMetalCompatibilityKey as String: true,
      ]
      var newPool: CVPixelBufferPool?
      CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &newPool)
      pool = newPool
      poolWidth = width
      poolHeight = height
      poolFormat = format
    }
    guard let pool = pool else { return nil }
    var buffer: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
    return status == kCVReturnSuccess ? buffer : nil
  }
}
