angular.module('s3-uploader', [])
.provider("S3Uploader", ->
  provider = {
    $get: ['$q', 'randomString', ($q, randomString) ->
      {
      upload: (file) ->
        # Configure The S3 Object
        AWS.config.update({ accessKeyId: provider.credentials.access_key, secretAccessKey: provider.credentials.secret_key });
        AWS.config.region = provider.credentials.region
        bucket = new AWS.S3({params: { Bucket: provider.credentials.bucket }, signatureVersion: 'v4'});
        filename = randomString(15) + '_' + file.name
        params = { Key: filename, ContentType: file.type, Body: file, ACL: 'public-read' };
        deferred = $q.defer()

        bucket.putObject params, (err, data) ->
          if (err)
            deferred.reject(err)
          else
            request = this.request.httpRequest
            file_url = request.endpoint.protocol + '//' + request.endpoint.host + request.path
            deferred.resolve(file_url)

        .on 'httpUploadProgress', (progress) ->
          deferred.notify(Math.round(progress.loaded / progress.total * 100));

        deferred.promise
      }
    ],
    credentials: {
      access_key: '',
      secret_key: '',
      bucket: '',
      region: ''
    }
  }
  provider
)
.directive('remoteUpload', ['S3Uploader', '$parse', '$compile', (S3Uploader, $parse, $compile) ->
  {
    require: 'ngModel',
    restrict: 'A',
    scope: {
      model: '=ngModel',
      afterUpload: '&afterFileUpload'
    }
    link: (scope, elem, attrs) ->

      scope.file = null
      isDrop     = angular.isDefined attrs.dragdrop
      isMultiple = angular.isDefined attrs.multiple

      # ng-file-upload directives
      if isDrop
        elem.attr 'ng-file-drop', ''
        elem.attr 'allowDir',     'false'
      else
        elem.attr 'ng-file-select', ''

      # Add common directives
      elem.removeAttr 'remote-upload'
      elem.removeAttr 'multiple'

      elem.attr 'ng-model',       'file'
      elem.attr('accept', '.p12,image/*') if !elem.attr('accept')
      elem.attr 'ng-multiple',    (isMultiple) ? 'true' : 'false'

      $compile(elem)(scope)

      fieldName = $parse(attrs.name)

      setProgress = (progress_obj) ->
        fieldName.assign scope.$parent, progress_obj
      getProgress = ->
        fieldName(scope.$parent)

      scope.$watch 'file', (values) ->
        if values
          if isMultiple
            scope.model = [] if !angular.isArray(scope.model)
            angular.forEach values, (value) ->
              scope.model.push({ file: value, file_name: value.name, upload_progress: 0, file_uploading: true })
              value.fileQueue = scope.model.length
            angular.forEach values, (value) ->
              fileIndex = value.fileQueue - 1
              S3Uploader.upload(value).then (filename) ->
                scope.model[fileIndex].remote_file_url = filename
                scope.afterUpload({file: scope.model[fileIndex]}) if scope.afterUpload
              ,(rejection) ->
                scope.model[fileIndex].error = rejection
                scope.model[fileIndex].upload_progress = 0
              ,(progress) ->
                scope.model[fileIndex].upload_progress = progress

          else
            setProgress({ progress: 0 })
            S3Uploader.upload(values[0]).then (filename) ->
              scope.model = filename
              scope.afterUpload({file: scope.model}) if scope.afterUpload
            ,(rejection) ->
              setProgress({ error: rejection, progress: 0 })
            ,(progress) ->
              setProgress({ progress: progress })

  }
])
