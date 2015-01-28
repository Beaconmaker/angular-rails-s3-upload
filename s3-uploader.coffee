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
      model: '=ngModel'
    }
    link: (scope, elem, attrs) ->

      scope.file = null
      isDrop = angular.isDefined attrs.dragdrop

      # ng-file-upload directives
      if isDrop
        elem.attr 'ng-file-drop', ''
        elem.attr 'allowDir',     'false'
      else
        elem.attr 'ng-file-select', ''

      # Add common directives
      elem.removeAttr 'remote-upload'

      elem.attr 'ng-model',       'file'
      elem.attr 'accept',         'image/*'
      elem.attr 'ng-multiple',    'false'

      $compile(elem)(scope)

      fieldName = $parse(attrs.name)

      scope.$watch 'file', (value) ->
        if value
          fieldName.assign scope.$parent, { progress: 0 }

          S3Uploader.upload(value[0]).then (filename) ->
            scope.model = filename
          ,(rejection) ->
            fieldName.assign scope.$parent, { error: rejection, progress: 0 }
          ,(progress) ->
            fieldName.assign scope.$parent, { progress: progress }
  }
])
