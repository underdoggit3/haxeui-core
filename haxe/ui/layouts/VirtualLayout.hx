package haxe.ui.layouts;

import haxe.ui.containers.IVirtualContainer;
import haxe.ui.core.BasicItemRenderer;
import haxe.ui.core.Component;
import haxe.ui.core.IDataComponent;
import haxe.ui.core.ItemRenderer;
import haxe.ui.core.UIEvent;
import haxe.ui.data.DataSource;

class VirtualLayout extends ScrollViewLayout {
    private var _firstIndex:Int = -1;
    private var _lastIndex:Int = -1;
    private var _rendererPool:Array<ItemRenderer> = [];
    private var _sizeCache:Array<Float> = [];

    private var contents(get, null):Component;
    private function get_contents():Component {
        if (contents == null) {
            contents = findComponent("scrollview-contents", false, "css");
        }

        return contents;
    }

    private var dataSource(get, never):DataSource<Dynamic>;
    private function get_dataSource():DataSource<Dynamic> {
        return cast(_component, IDataComponent).dataSource;
    }

    public override function refresh() {
        refreshData();

        super.refresh();
    }

    private function refreshData() {
        if (dataSource == null) {
            return;
        }

        var comp:IVirtualContainer = cast(_component, IVirtualContainer);
        if (comp.virtual == false) {
            refreshNonVirtualData();
        } else {
            refreshVirtualData();
        }
    }

    private function refreshNonVirtualData() {
        var dataSource:DataSource<Dynamic> = dataSource;
        var contents:Component = this.contents;
        for (n in 0...dataSource.size) {
            var data:Dynamic = dataSource.get(n);
            var item:ItemRenderer = null;
            if (n < contents.childComponents.length) {
                item = cast contents.childComponents[n];
                if (item.data == data) {
                    continue;
                }

                var cls = itemClass(n, data);
                if (Std.is(item, cls)) {
                } else {
                    removeRenderer(item);
                    item = getRenderer(cls, n);
                    _component.addComponentAt(item, n);
                }
            } else {
                var cls = itemClass(n, data);
                item = getRenderer(cls, n);
                _component.addComponent(item);
            }

            var className:String = n % 2 == 0 ? "even" : "odd";
            if (!item.hasClass(className)) {
                var inverseClassName = n % 2 == 0 ? "odd" : "even";
                item.removeClass(inverseClassName);
                item.addClass(className);
            }

            item.data = data;
        }

        while (dataSource.size < contents.childComponents.length) {
            var item:ItemRenderer = cast contents.childComponents[contents.childComponents.length - 1];
            removeRenderer(item);    // remove last
        }
    }

    private function refreshVirtualData() {
        removeInvisibleRenderers();
        calculateRangeVisible();
        updateScroll();

        var dataSource:DataSource<Dynamic> = dataSource;
        var i = 0;
        for (n in _firstIndex..._lastIndex) {
            var data:Dynamic = dataSource.get(n);

            var item:ItemRenderer = null;
            var cls = itemClass(n, data);
            if (contents.childComponents.length <= i) {
                item = getRenderer(cls, n);
                _component.addComponent(item);
            } else {
                item = cast contents.childComponents[i];

                //Renderers are always ordered
                if (!Std.is(item, cls)) {
                    item = getRenderer(cls, n);
                    _component.addComponentAt(item, i);
                } else if (item.itemIndex != n) {
                    removeRenderer(item, false);
                    item = getRenderer(cls, n);
                    _component.addComponentAt(item, i);
                }
            }

            var className:String = n % 2 == 0 ? "even" : "odd";
            if (!item.hasClass(className)) {
                var inverseClassName = n % 2 == 0 ? "odd" : "even";
                item.removeClass(inverseClassName);
                item.addClass(className);
            }

            item.data = data;

            i++;
        }

        while (contents.childComponents.length > i) {
            removeRenderer(cast contents.childComponents[contents.childComponents.length - 1], false);    // remove last
        }
    }

    private function calculateRangeVisible() {

    }

    private function updateScroll() {

    }

    private function itemClass(index:Int, data:Dynamic):Class<ItemRenderer> {
        var comp:IVirtualContainer = cast(_component, IVirtualContainer);
        if (comp.itemRendererFunction != null) {
            return comp.itemRendererFunction(data, index);
        } else if (comp.itemRendererClass != null) {
            return comp.itemRendererClass;
        } else {
            return BasicItemRenderer;
        }
    }

    private function getRenderer(cls:Class<ItemRenderer>, index:Int):ItemRenderer {
        var instance:ItemRenderer = null;
        var comp:IVirtualContainer = cast(_component, IVirtualContainer);
        if (comp.virtual == true) {
            for (i in 0..._rendererPool.length) {
                var renderer = _rendererPool[i];
                if (Std.is(renderer, cls)) {
                    _rendererPool.splice(i, 1);
                    instance = renderer;
                    break;
                }
            }
        }

        if (instance == null) {
            var comp:IVirtualContainer = cast(_component, IVirtualContainer);
            if (comp.itemRenderer != null) {
                instance = comp.itemRenderer.cloneComponent();
            } else {
                instance = Type.createInstance(cls, []);
            }
        }

        instance.itemIndex = index;
        if (_component.hasEvent(UIEvent.RENDERER_CREATED)) {
            _component.dispatch(new UIEvent(UIEvent.RENDERER_CREATED, instance));
        }

        return cast(instance, ItemRenderer);
    }

    private function removeRenderer(renderer:ItemRenderer, dispose:Bool = true) {
        _component.removeComponent(renderer, dispose);

        var comp:IVirtualContainer = cast(_component, IVirtualContainer);
        if (comp.virtual == true) {
            _rendererPool.push(cast(renderer, ItemRenderer));
        }

        if (_component.hasEvent(UIEvent.RENDERER_DESTROYED)) {
            _component.dispatch(new UIEvent(UIEvent.RENDERER_DESTROYED, renderer));
        }

        renderer.itemIndex = -1;
    }

    private function removeInvisibleRenderers() {
        var contents:Component = this.contents;
        if (_firstIndex >= 0) {
            while (contents.childComponents.length > 0 && !isRendererVisible(contents.childComponents[0])) {
                removeRenderer(cast contents.childComponents[0], false);
                ++_firstIndex;
            }
        }

        if (_lastIndex >= 0) {
            while (contents.childComponents.length > 0 && !isRendererVisible(contents.childComponents[contents.childComponents.length - 1])) {
                removeRenderer(cast contents.childComponents[contents.childComponents.length - 1], false);
                --_lastIndex;
            }
        }
    }

    private function isRendererVisible(renderer:Component):Bool {
        return renderer.top < _component.componentHeight &&
        renderer.top + renderer.componentHeight >= 0 &&
        renderer.left < _component.componentWidth &&
        renderer.left + renderer.componentWidth >= 0;
    }

    private inline function isIndexVisible(index:Int):Bool {
        return index >= _firstIndex && index <=_lastIndex;
    }
}