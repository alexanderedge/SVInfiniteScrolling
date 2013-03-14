This is a fork of Sam Vermette's [SVPullToRefresh](https://github.com/samvermette/SVPullToRefresh) repository that supports infinite scrolling in __both directions__. SVPullToRefresh category is not included in this repository.

_**If your project doesn't use ARC**: you must add the `-fobjc-arc` compiler flag to `UIScrollView+SVInfiniteScrolling.m` in Target Settings > Build Phases > Compile Sources._

# SVInfiniteScrolling

This UIScrollView category makes it super easy to add infinite scrolling functionality to any UIScrollView (or any of its subclass). Instead of relying on delegates and/or subclassing `UIViewController`, SVInfiniteScrolling uses the Objective-C runtime to add the following 2 methods to `UIScrollView`:

```objective-c
- (void)addInfiniteScrollingWithActionHandler:(void (^)(void))actionHandler forPosition:(SVInfiniteScrollingPositionTop)position;
```

## Installation

* Drag the `SVInfiniteScrolling/SVInfiniteScrolling` folder into your project.
* Add the **QuartzCore** framework to your project.
* Import `UIScrollView+SVInfiniteScrolling.h`

## Usage

(see sample Xcode project in `/Demo`)

### Adding Infinite Scrolling

```objective-c
[tableView addInfiniteScrollingWithActionHandler:^{
    // append data to data source, insert new cells at the end of table view
    // call [tableView.infiniteScrollingView stopAnimating] when done
} forPosition:SVInfiniteScrollPositionTop];
```

If you’d like to programmatically trigger the loading (for instance in `viewDidAppear:`), you can do so with:

```objective-c
[tableView triggerInfiniteScrollingForPosition:SVInfiniteScrollPositionTop];
```

You can temporarily hide the infinite scrolling view by setting the `showsInfiniteScrolling` property:

```objective-c
[tableView setShowsInfiniteScrolling:NO forPosition:SVInfiniteScrollPositionTop];
```

#### Customization

The infinite scrolling view can be customized using the following methods:

```objective-c
- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)activityIndicatorViewStyle;
- (void)setCustomView:(UIView *)view forState:(SVInfiniteScrollingState)state;
```

You can access these properties through your scroll view's `infiniteScrollingView` property. 

## Under the hood

SVInfiniteScrolling extends `UIScrollView` by adding new public methods as well as a dynamic properties. 

It uses key-value observing to track the scrollView's `contentOffset`.

## Credits

SVPullToRefresh is brought to you by [Sam Vermette](http://samvermette.com) and [contributors to the project](https://github.com/samvermette/SVPullToRefresh/contributors). If you have feature suggestions or bug reports, feel free to help out by sending pull requests or by [creating new issues](https://github.com/samvermette/SVPullToRefresh/issues/new). If you're using SVPullToRefresh in your project, attribution would be nice. 

Big thanks to [@seb_morel](http://twitter.com/seb_morel) for his [Demistifying the Objective-C runtime](http://cocoaheadsmtl.s3.amazonaws.com/demistifying-runtime.pdf) talk which really helped for this project. 

Hat tip to [Loren Brichter](http://twitter.com/lorenb) for inventing pull-to-refresh.
