Video Edit in iOS by Swift
==========================

主要功能
----
 * 视频快照
 * 视频合并
 * 视频裁剪

 
<a href="https://github.com/ripplek/VideoEditDemo/tree/master/VideoEditDemo_Swift/Example">Example</a>
----

VideoEditingManager 核心类
----
- delegate: VideoEditingDelegate
	* `func videoExportWillStart(session: AVAssetExportSession)`
	* `func videoExportDidFinish(session: AVAssetExportSession)`

- publicAPI：
	* `public func getImageFromVideo(asset: AVAsset, shotTime: Double) -> UIImage?`
	
	* `public func mergeVideo(_ assets: [AVAsset], savePath: URL? = nil)`
	
	* `public func editAndSynthesizeVideo(_ asset: AVAsset, ranges: [(starTime: Float64, duration: Float64)], savePath: URL? = nil)`
	
	
