/// Copyright (c) 2018 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Metal
import simd

class ViewController: UIViewController {
  
  var device: MTLDevice!
  var metalLayer: CAMetalLayer!
  var vertexBuffer: MTLBuffer!
  
  var pipelineState: MTLRenderPipelineState!
  
  var commandQueue: MTLCommandQueue!
  
  var timer: CADisplayLink!
  
  var transformMatrix: CGAffineTransform!
  
  // Vertexes of triangle
  var vertexData: [Float] = [
    0.0,  -1.0, 0.0,
    -1.0, -1.0, 0.0,
    1.0, -1.0, 0.0
  ]
  
  var pointsToDraw = [CGPoint]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    transformMatrix = CGAffineTransform(a: 2.0/view.layer.frame.width,
                                        b: 0.0, c: 0.0,
                                        d: -2.0/view.layer.frame.height,
                                        tx: -1.0, ty: 1.0)
    
    for i in 0..<100 {
      let x = CGFloat(arc4random()).truncatingRemainder(dividingBy: 2) == 0 ? i*4 : i / 4
      let y = CGFloat(arc4random()).truncatingRemainder(dividingBy: 2) == 0 ? i*4 : i / 4
      
      pointsToDraw.append(CGPoint(x: x, y: y))
    }
    
    let vertexes = pointsToDraw.map({ $0.applying(transformMatrix) })
      .map({ return [Float($0.x), Float($0.y), 0] }).joined()
    
    vertexData = Array(vertexes)
    
    device = MTLCreateSystemDefaultDevice()
    commandQueue = device.makeCommandQueue()
    
    configureMetalLayer()
    prepareBuffer()
    preparePipeline()
    prepareDisplayLink()
  }
  
  private func configureMetalLayer() {
    metalLayer = CAMetalLayer()
    metalLayer.device = device
    metalLayer.pixelFormat = .bgra8Unorm
    metalLayer.framebufferOnly = true
    metalLayer.frame = view.layer.frame
    view.layer.addSublayer(metalLayer)
  }
  
  private func prepareBuffer() {
    let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
    vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
  }
  
  private func preparePipeline() {
    // 1
    let defaultLibrary = device.makeDefaultLibrary()!
    let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")
    let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")
    
    // 2
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexFunction = vertexProgram
    pipelineStateDescriptor.fragmentFunction = fragmentProgram
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    
    // 3
    pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
  }
  
  private func prepareDisplayLink() {
    timer = CADisplayLink(target: self, selector: #selector(gameloop))
    timer.add(to: RunLoop.main, forMode: .default)
  }
  
  func render() {
    if  vertexData.count > 2 {
      let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
      vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
      
      guard let drawable = metalLayer?.nextDrawable() else { return }
      let renderPassDescriptor = MTLRenderPassDescriptor()
      renderPassDescriptor.colorAttachments[0].texture = drawable.texture
      renderPassDescriptor.colorAttachments[0].loadAction = .clear
      renderPassDescriptor.colorAttachments[0].clearColor =  MTLClearColor(red: 255.0, green: 255.0, blue: 255.0, alpha: 1.0)
      
      let commandBuffer = commandQueue.makeCommandBuffer()
      
      let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
      renderEncoder?.setRenderPipelineState(pipelineState)
      renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
      
      let color = UIColor.blue.rgb()!
      
      var fragmentColor = vector_float4(Float(color.red),
                                        Float(color.green),
                                        Float(color.blue),
                                        Float(color.alpha))
      
      renderEncoder?.setFragmentBytes(&fragmentColor, length: MemoryLayout.size(ofValue: fragmentColor), index: 0)
      
      renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertexData.count / 3)
      
      renderEncoder?.endEncoding()
      
      commandBuffer?.present(drawable)
      commandBuffer?.commit()
    }
  }
  
  @objc func gameloop() {
    autoreleasepool {
      self.render()
    }
  }

  
}

extension UIColor {
  
  func rgb() -> (red:Int, green:Int, blue:Int, alpha:Int)? {
    var fRed : CGFloat = 0
    var fGreen : CGFloat = 0
    var fBlue : CGFloat = 0
    var fAlpha: CGFloat = 0
    if self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
      let iRed = Int(fRed * 255.0)
      let iGreen = Int(fGreen * 255.0)
      let iBlue = Int(fBlue * 255.0)
      let iAlpha = Int(fAlpha * 255.0)
      
      return (red:iRed, green:iGreen, blue:iBlue, alpha:iAlpha)
    } else {
      // Could not extract RGBA components:
      return nil
    }
  }
}
