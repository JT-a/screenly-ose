
@screenly = window.screenly ? {}
@screenly.collections = window.screenly.collections ? {}
@screenly.views = window.screenly.views ? {}
@screenly.models = window.screenly.models ? {}


# Tell Backbone to send its saves as JSON-encoded.
Backbone.emulateJSON = true


################################
# Utilities
################################

localizedDateString = (string) ->
  date = new Date(string)
  offset = date.getTimezoneOffset()
  (new Date(date.getTime() - (offset * 60000))).toISOString()


################################
# Models
################################

class Asset extends Backbone.Model
  url: ->
    if @get('asset_id')
      "/api/assets/#{@get('asset_id')}"

screenly.models.Asset = Asset

################################
# Collections
################################

class Assets extends Backbone.Collection
  url: "/api/assets"
  model: Asset
  
  initialize: (options) ->
    @on "reset", ->
      screenly.ActiveAssets.reset()
      screenly.InactiveAssets.reset()

      @each (model) ->
        if model.get('is_active')
          screenly.ActiveAssets.add model
        else
          screenly.InactiveAssets.add model

screenly.Assets = new Assets()

class ActiveAssets extends Backbone.Collection
  model: Asset

class InactiveAssets extends Backbone.Collection
  model: Asset

screenly.collections.Assets = Assets
screenly.collections.ActiveAssets = ActiveAssets
screenly.collections.InactiveAssets = InactiveAssets

screenly.ActiveAssets = new ActiveAssets()
screenly.InactiveAssets = new InactiveAssets()

################################
# Views
################################

class AddAssetModalView extends Backbone.View

  events:
    'click #add-button': 'addButtonWasClicked'

  initialize: (options) ->
    @template = _.template($('#add-asset-modal-template').html())

  render: ->
    $(@el).html(@template())
    
    @$("input.date").datepicker({autoclose: true})
    @$("input.date").datepicker('setValue', new Date())

    @$('input.time').timepicker({
      minuteStep: 5,
      showInputs: false,
      disableFocus: true,
      defaultTime: 'current',
      showMeridian: false
    })

    @

  addButtonWasClicked: (event) ->
    event.preventDefault()
    console.log "You tried to add Asset"

    start_date = $("input[name='start_date_date']").val() + " " + $("input[name='start_date_time']").val()
    end_date = $("input[name='end_date_date']").val() + " " + $("input[name='end_date_time']").val()

    $("input[name='start_date']").val(localizedDateString(start_date))
    $("input[name='end_date']").val(localizedDateString(end_date))

    @$("form").submit()


screenly.views.AddAssetModalView = AddAssetModalView

class EditAssetModalView extends Backbone.View

class AssetsView extends Backbone.View
  initialize: (options) ->

    if not 'templateName' in options
      console.log "You need to specify the template name for this AssetsView."

    if not 'childViewClass' in options
      console.log "You must specify the child view class for this AssetsView."

    @template = _.template($('#' + options.templateName).html())
    
    @collection.bind "reset", @render, @
    @collection.bind "remove", @render, @
    @collection.bind "add", @render, @

  render: ->
    $(@el).html(@template())

    # TODO This can be cleaned up to not re-render everything all the time.
    
    @$('tbody').empty()
    @collection.each (asset) =>
      @$('tbody').append (new @options['childViewClass']({model: asset})).render().el

    @

class ActiveAssetRowView extends Backbone.View

  initialize: (options) ->
    @template = _.template($('#active-asset-row-template').html())

  events:
    'click #deactivate': 'deactivateAsset'

  tagName: "tr"

  render: ->
    $(@el).html(@template(@model.toJSON()))
    @

  deactivateAsset: (event) ->

    # To deactivate, set this asset's end_date to right now
    @model.set('end_date', localizedDateString(new Date()))

    # Now persist the change on the server so this becomes
    # active immediately.
    @model.save()

    # Now let's update the local collections, which
    # should change the view the user sees. Let's delay
    # this for 1 second to allow the animation to
    # complete.
    setTimeout (=> 
      screenly.ActiveAssets.remove(@model)
      screenly.InactiveAssets.add(@model)
    ), 500


class InactiveAssetRowView extends Backbone.View

  initialize: (options) ->
    @template = _.template($('#inactive-asset-row-template').html())

  events:
    'click #activate': 'activateAsset'

  tagName: "tr"

  render: ->
    $(@el).html(@template(@model.toJSON()))
    @

  activateAsset: (event) ->

    # To "activate" an asset, we set its start_date
    # to now and, for now, set its end_date to
    # 10 years from now.
    @model.set('start_date', localizedDateString(new Date()))
    @model.set('end_date', localizedDateString((new Date()).getTime() + (10 * 365 * 24 * 60 * 60000) ))
    @model.save()

    # Now let's update the local collections, which
    # should change the view the user sees.
    setTimeout (=> 
      screenly.InactiveAssets.remove @model
      screenly.ActiveAssets.add @model
    ), 500

screenly.views.AssetsView = AssetsView
screenly.views.ActiveAssetRowView = ActiveAssetRowView

jQuery ->
  
  screenly.Assets.fetch()

  # Initialize the initial view
  activeAssetsView = new AssetsView(
    collection: screenly.ActiveAssets, 
    templateName: "active-assets-template", 
    childViewClass: ActiveAssetRowView
  )

  inactiveAssetsView = new AssetsView(
    collection: screenly.InactiveAssets,
    templateName: "inactive-assets-template",
    childViewClass: InactiveAssetRowView
  )

  $("#active-assets-container").append activeAssetsView.render().el
  $("#inactive-assets-container").append inactiveAssetsView.render().el

  $("#add-asset-button").click (event) ->
    event.preventDefault()
    modal = new AddAssetModalView()
    $("body").append modal.render().el
    $(modal.el).children(":first").modal()
