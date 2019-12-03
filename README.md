# VideoCache

VideoCache is an AVPlayerItem Cache library written in Swift.

## Example

```swift

// import
import VideoCache

// setup
VideoCacheManager.logLevel = .error
VideoCacheManager.default.capacityLimit = Int64(1).GB
.
.
.
// cache all
let playerItem = AVPlayerItem(remote: url, cacheKey: <#special key for this media or nil#>)
let player = AVPlayer(playerItem: playerItem)
.
.
// cache 0~1024, 2048~4096
let playerItem = AVPlayerItem(remote: url, cacheKey: <#special key for this media or nil#>, cacheRanges: [0...1024, 2048...4096])
let player = AVPlayer(playerItem: playerItem)
```


### Carthage

[Carthage](https://github.com/SoalHuang/VideoCache) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks. To integrate VideoCache into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "SoalHuang/VideoCache"
```


## Author
* *** Twitter: [@SoalHuang](https://twitter.com/SoalHuang) ***

## Reference
* *** [VIMediaCache](https://github.com/vitoziv/VIMediaCache) ***

## License

VideoCache is available under the MIT license. See the LICENSE file for more info.
