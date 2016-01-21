# View class to control how At.js's view showing.
# All classes share the same DOM view.
class View

  # @param controller [Object] The Controller.
  constructor: (@context) ->
    @$el = $("<div class='atwho-view'><ul class='atwho-view-ul'></ul></div>")
    @timeoutID = null
    # create HTML DOM of list view if it does not exist
    @context.$el.append(@$el)
    this.bindEvent()

  init: ->
    id = @context.getOpt("alias") || @context.at.charCodeAt(0)
    @$el.attr('id': "at-view-#{id}")

  destroy: ->
    @$el.remove()

  bindEvent: ->
    $menu = @$el.find('ul')
    # -------------------------------------------------------------------------
    # FIX START
    #
    # https://zendesk.atlassian.net/browse/AI-4215
    #
    # Navigating with the keyboard through the menu may cause its scrolling
    # which in turn may trigger a mousemove/mouseenter/mouseover event without
    # actually moving the mouse.
    #
    # With the fix, the system memorizes the last actual position of the mouse
    # and if a mouse event fires while the mouse position hasn't changed, the
    # event must have been triggered by movement of the LI elements (not the
    # mouse itself).
    #
    # The "mousemove" event is used instead of the "mouseenter", as "mousemove"
    # allows for the immediate tracking of the mouse move after menu scrolling.
    # If "mouseenter" is used, when moving the mouse over the item over which
    # the mouse pointer is already positioned then the event won't fire.
    # -------------------------------------------------------------------------
    lastCoordX = 0
    lastCoordY = 0
    $menu.on 'mousemove.atwho-view','li', (e) =>
      # If the mouse hasn't actually moved then exit.
      return if lastCoordX == e.clientX and lastCoordY == e.clientY
      lastCoordX = e.clientX
      lastCoordY = e.clientY
      $cur = $(e.currentTarget)
      return if $cur.hasClass('cur')
      $menu.find('.cur').removeClass 'cur'
      $cur.addClass 'cur'
    # -------------------------------------------------------------------------
    # FIX END
    # -------------------------------------------------------------------------
    .on 'click.atwho-view', 'li', (e) =>
      $menu.find('.cur').removeClass 'cur'
      $(e.currentTarget).addClass 'cur'
      this.choose(e)
      e.preventDefault()

  # Check if view is visible
  #
  # @return [Boolean]
  visible: ->
    @$el.is(":visible")

  highlighted: ->
    @$el.find(".cur").length > 0

  choose: (e) ->
    if ($li = @$el.find ".cur").length
      content = @context.insertContentFor $li

      @context._stopDelayedCall()
      @context.insert @context.callbacks("beforeInsert").call(@context, content, $li), $li
      @context.trigger "inserted", [$li, e]
      this.hide(e)
    @stopShowing = yes if @context.getOpt("hideWithoutSuffix")

  reposition: (rect) ->
    _window = if @context.app.iframeAsRoot then @context.app.window else window
    if rect.bottom + @$el.height() - $(_window).scrollTop() > $(_window).height()
      rect.bottom = rect.top - @$el.height()
    if rect.left > overflowOffset = $(_window).width() - @$el.width() - 5
      rect.left = overflowOffset
    offset = {left:rect.left, top:rect.bottom}
    @context.callbacks("beforeReposition")?.call(@context, offset)
    @$el.offset offset
    @context.trigger "reposition", [offset]

  next: ->
    cur = @$el.find('.cur').removeClass('cur')
    next = cur.next()
    next = @$el.find('li:first') if not next.length
    next.addClass 'cur'

    @scrollTop Math.max(0, cur.innerHeight() * (next.index() + 2) - @$el.height())

  prev: ->
    cur = @$el.find('.cur').removeClass('cur')
    prev = cur.prev()
    prev = @$el.find('li:last') if not prev.length
    prev.addClass 'cur'

    @scrollTop Math.max(0, cur.innerHeight() * (prev.index() + 2) - @$el.height())

  scrollTop: (scrollTop) ->
    scrollDuration = @context.getOpt('scrollDuration')
    if scrollDuration
      @$el.animate {scrollTop: scrollTop}, scrollDuration
    else
      @$el.scrollTop(scrollTop)

  show: ->
    if @stopShowing
      @stopShowing = false
      return
    if not this.visible()
      @$el.show()
      @$el.scrollTop 0
      @context.trigger 'shown'
    this.reposition(rect) if rect = @context.rect()

  hide: (e, time) ->
    return if not this.visible()
    if isNaN(time)
      @$el.hide()
      @context.trigger 'hidden', [e]
    else
      callback = => this.hide()
      clearTimeout @timeoutID
      @timeoutID = setTimeout callback, time

  # render list view
  render: (list) ->
    if not ($.isArray(list) and list.length > 0)
      this.hide()
      return

    @$el.find('ul').empty()
    $ul = @$el.find('ul')
    tpl = @context.getOpt('displayTpl')

    for item in list
      item = $.extend {}, item, {'atwho-at': @context.at}
      li = @context.callbacks("tplEval").call(@context, tpl, item, "onDisplay")
      $li = $ @context.callbacks("highlighter").call(@context, li, @context.query.text)
      $li.data("item-data", item)
      $ul.append $li

    this.show()
    $ul.find("li:first").addClass "cur" if @context.getOpt('highlightFirst')
