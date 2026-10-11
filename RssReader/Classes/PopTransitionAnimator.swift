//
//  PopTransitionAnimator.swift
//  RssReader
//
//  Created by Simon Ng on 4/6/15.
//  Copyright (c) 2015 AppCoda Limited. All rights reserved.
//

import UIKit

class PopTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerTransitioningDelegate {
    var isPresenting = false
    var duration = 0.3
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        // Get reference to our fromView, toView and the container view
        guard let fromVC = transitionContext.viewController(forKey: .from) else { return}
        guard let toVC = transitionContext.viewController(forKey: .to) else { return}
        guard let fromView = fromVC.view else { return }
        guard let toView = toVC.view else { return }

        // Adapt for orientation changes
        toView.frame = fromView.bounds
        
        // Set up the transform we'll use in the animation
        let container = transitionContext.containerView
        let minimize = CGAffineTransform(scaleX: 0, y: 0)
        let offScreenDown = CGAffineTransform(translationX: 0, y: container.frame.height)
        
        let shiftDown = CGAffineTransform(translationX: 0, y: 15)
        let scaleDown = shiftDown.scaledBy(x: 0.95, y: 0.95)
        
        // Change the initial size of the toView
        if isPresenting {
            toView.layer.anchorPoint = CGPoint(x:0, y:0)
            toView.layer.position = CGPoint(x:0, y:0)
            toView.transform = minimize
        } else {
            toView.transform = scaleDown
        }
        
        // Add both views to the container view
        if isPresenting {
            container.addSubview(fromView)
            container.addSubview(toView)
        } else {
            container.addSubview(toView)
            container.addSubview(fromView)
        }
        
        // Perform the animation
        UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.8, options: UIView.AnimationOptions(), animations: {
            
            if self.isPresenting {
                fromView.alpha = 0.5
                toView.transform = CGAffineTransform.identity
            } else {
                fromView.transform = offScreenDown
                toView.alpha = 1.0
                toView.transform = CGAffineTransform.identity
            }
            
            }, completion: { finished in
                
                transitionContext.completeTransition(finished)
                
        })
        
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        isPresenting = false
        return self
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        isPresenting = true
        return self
    }
    
}

