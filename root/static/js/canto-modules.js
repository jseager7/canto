'use strict';

/*global curs_root_uri,angular,$,make_ontology_complete_url,ferret_choose,application_root,window,canto_root_uri,curs_key,bootbox,app_static_path */

var canto = angular.module('cantoApp', ['ui.bootstrap', 'toaster']);

function capitalize (text) {
  return text.charAt(0).toUpperCase() + text.slice(1).toLowerCase();
}

function countKeys(o) {
  var size = 0, key;
  for (key in o) {
    if (key.indexOf('$$') !== 0 && o.hasOwnProperty(key)) {
      size++;
    }
  }
  return size;
}

function arrayRemoveOne(array, item) {
  var i = array.indexOf(item);
  if (i >= 0) {
    array.splice(i, 1);
  }
}

function copyObject(src, dest, keysFilter) {
  Object.getOwnPropertyNames(src).forEach(function(key) {
    if (key.indexOf('$$') === 0) {
      // ignore AngularJS data
      return;
    }
    if (keysFilter) {
      if (!keysFilter[key]) {
        return;
      }
    }

    if (null == src[key] || "object" != typeof src[key]) {
      dest[key] = src[key];
      return;
    }

    if (src[key] instanceof Array) {
      dest[key] = [];
      for (var i = 0, len = src[key].length; i < len; i++) {
        dest[key][i] = src[key][i];
      }
      return;
    }

    if (src[key] instanceof Object) {
      dest[key] = {};
      copyObject(src[key], dest[key]);
    }
  });
}

// for each property in changedObj, copy to dest when it's different to origObj
function copyIfChanged(origObj, changedObj, dest) {
  Object.getOwnPropertyNames(changedObj).forEach(function(key) {
    if (changedObj[key] !== origObj[key]) {
      dest[key] = changedObj[key];
    }
  });
}

function simpleHttpPost(toaster, $http, url, data) {
  $http.post(url, data).
    success(function(data) {
      if (data.status === "success") {
        window.location.href = data.location;
      } else {
        toaster.pop('error', data.message);
      }
    }).
    error(function(data, status){
      toaster.pop('error', "Accessing server failed: " + (data || status) );
    });
}

function conditionsToString(conditions) {
  return $.map(conditions, function(el) { return el.name; }).join (", ");
}

canto.filter('breakExtensions', function() {
  return function(text) {
    if (typeof(text) === 'undefined') {
      return '';
    }
    return text.replace(/,/g, ', ').replace(/\|/, " | ");
  };
});

canto.config(function($logProvider){
    $logProvider.debugEnabled(true);
});

canto.service('Curs', function($http) {
  this.list = function(key, args) {
    var data = null;

    if (typeof(args) === 'undefined') {
      args = [];
    }

    var url = curs_root_uri + '/ws/' + key + '/list/';

    if (args.length > 0 && typeof(args[args.length - 1]) === 'object') {
      data = args.pop();
      return $http.post(url + args.join('/'), data);
    } else {
      return $http.get(url + args.join('/'));
    }
  };

  this.add = function(key, args) {
    if (typeof(args) === 'undefined') {
      args = [];
    }

    var url = curs_root_uri + '/ws/' + key + '/add/' + args.join('/');
    return $http.get(url);
  };
});

canto.service('CursGeneList', function($q, Curs) {
  this.geneList = function() {
    var q = $q.defer();

    Curs.list('gene').success(function(genes) {
      $.map(genes,
            function(gene) {
              gene.feature_id = gene.gene_id;
            });
      q.resolve(genes);
    }).error(function() {
      q.reject();
    });

    return q.promise;
  };
});

canto.service('CursGenotypeList', function($q, Curs) {
  this.cursGenotypesPromise = Curs.list('genotype', ['curs_only']);

  function add_id_or_identifier(genotypes) {
    $.map(genotypes, function(genotype) {
      genotype.id_or_identifier = genotype.genotype_id || genotype.identifier;
      genotype.feature_id = genotype.genotype_id;
    });
  };

  this.cursGenotypeList = function() {
    var q = $q.defer();

    this.cursGenotypesPromise.success(function(genotypes) {
      add_id_or_identifier(genotypes);
      q.resolve(genotypes);
    }).error(function() {
      q.reject();
    });

    return q.promise;
  };

  this.filteredGenotypeList = function(filter) {
    var options = {
      filter: filter,
    };
    var filteredCursPromise =
      Curs.list('genotype', ['all', options]);

    var q = $q.defer();

    filteredCursPromise.success(function(genotypes) {
      add_id_or_identifier(genotypes);
      q.resolve(genotypes);
    }).error(function() {
      q.reject();
    });

    return q.promise;
  };
});

canto.service('CursAlleleList', function($q, Curs) {
  this.alleleList = function(genePrimaryIdentifier, searchTerm) {
    var q = $q.defer();

    Curs.list('allele', [genePrimaryIdentifier, searchTerm])
      .success(function(alleles) {
        q.resolve(alleles);
      })
      .error(function() {
        q.reject();
      });

    return q.promise;
  };
});

canto.service('CursConditionList', function($q, Curs) {
  this.conditionList = function() {
    var q = $q.defer();

    Curs.list('condition').success(function(conditions) {
      q.resolve(conditions);
    }).error(function() {
      q.reject();
    });

    return q.promise;
  };
});

canto.service('CantoGlobals', function($window) {
  this.app_static_path = $window.app_static_path;
  this.application_root = $window.application_root;
  this.curs_root_uri = $window.curs_root_uri;
  this.ferret_choose = $window.ferret_choose;
});

canto.service('CantoService', function($http) {
  this.lookup = function(key, path_parts, params, timeout) {
    return $http.get(application_root + '/ws/lookup/' + key + '/' +
                     path_parts.join('/'),
                     {
                       params: params,
                       timeout: timeout
                     });
  };
});

var keysForServer = {
  annotation_extension: true,
  annotation_type: true,
  evidence_code: true,
  feature_id: true,
  feature_type: true,
//  is_not: true,
//  qualifiers: true,
  submitter_comment: true,
  term_ontid: true,
  term_suggestion_name: true,
  term_suggestion_definition: true,
  with_gene_id: true,
  interacting_gene_id: true,
};

var annotationProxy =
  function(Curs, $q, $http) {
  this.allAnnotationQ = undefined;

  this.getAllAnnotation = function() {
    if (typeof(this.allAnnotationQ) === 'undefined') {
      this.allAnnotationQ = Curs.list('annotation');
    }

    return this.allAnnotationQ;
  };

  // filter the list of annotation based on the params argument
  // possibilities:
  //   annotationTypeName (required)
  //   featureId (optional)
  //   featureType (optional)
  //   featureStatus (optional)
  this.getFiltered =
    function(params) {
      var q = $q.defer();

      this.getAllAnnotation().success(function(annotations) {
        var filteredAnnotations =
          $.grep(annotations,
                 function(elem) {
                   return elem.annotation_type === params.annotationTypeName &&
                     (!params.featureStatus ||
                      elem.status === params.featureStatus) &&
                     (!params.featureId ||
                      (params.featureType &&
                       ((params.featureType === 'gene' &&
                         (elem.gene_id == params.featureId ||
                          (typeof(elem.interacting_gene_id) !== 'undefined' &&
                           elem.interacting_gene_id == params.featureId)
                         )) ||
                       (params.featureType === 'genotype' &&
                        elem.genotype_id == params.featureId))));
                 });
        q.resolve(filteredAnnotations);
      }).error(function() {
        q.reject();
      });

      return q.promise;
    };

    this.deleteAnnotation = function(annotation) {
      var q = $q.defer();

      var details = { key: curs_key,
                      annotation_id: annotation.annotation_id };

      var putQ = $http.put(curs_root_uri + '/ws/annotation/delete', details);

      putQ.success(function(response) {
        if (response.status === 'success') {
          q.resolve();
        } else {
          q.reject(response.message);
        }
      }).error(function(data, status) {
        q.reject('Deletion request to server failed: ' + status);
      });

      return q.promise;
    };

  this.storeChanges = function(annotation, changes, newly_added) {
    var q = $q.defer();

    var changesToStore = {};

    if (newly_added) {
      // special case, copy everything
      copyObject(changes, changesToStore, keysForServer);
    } else {
      copyIfChanged(annotation, changes, changesToStore);

      if (countKeys(changesToStore) === 0) {
        q.reject('No changes to store');
        return q.promise;
      }

      if (changesToStore.feature_id) {
        changesToStore.feature_type = annotation.feature_type;
      }
    }

    changesToStore.key = curs_key;

    // we send term_ontid, so this is not needed
    delete changesToStore.term_name;

    var putQ;

    if (newly_added) {
      putQ = $http.put(curs_root_uri + '/ws/annotation/create', changesToStore);
    } else {
      putQ = $http.put(curs_root_uri + '/ws/annotation/' + annotation.annotation_id +
                       '/new/change', changesToStore);
    }
    putQ.success(function(response) {
      if (response.status === 'success') {
        // update local copy
        copyObject(response.annotation, annotation);
        q.resolve(annotation);
      } else {
        q.reject(response.message);
      }
    }).error(function() {
      q.reject();
    });

    return q.promise;
  };
};

canto.service('AnnotationProxy', ['Curs', '$q', '$http', annotationProxy]);

function fetch_conditions(search, showChoices) {
  $.ajax({
    url: make_ontology_complete_url('phenotype_condition'),
    data: { term: search.term, def: 1, },
    dataType: "json",
    success: function(data) {
      var choices = $.map( data, function( item ) {
        var label;
        if (typeof(item.matching_synonym) === 'undefined') {
          label = item.name;
        } else {
          label = item.matching_synonym + ' (synonym)';
        }
        return {
          label: label,
          value: item.name,
          name: item.name,
          definition: item.definition,
        };
      });
      showChoices(choices);
    },
  });
}

var cantoBreadcrumbsService =
  function($rootScope) {
    // var gene = null
    this.searchString = null;
    this.termHistory = [];
  };

canto.service('CantoBreadcrumbsService', ['$rootScope', cantoBreadcrumbsService]);


var breadcrumbsDirective =
  function($compile, CantoBreadcrumbsService) {
    return {
      scope: {
      },
      restrict: 'E',
      replace: true,
      controller: function($scope) {
        $scope.CantoBreadcrumbsService = CantoBreadcrumbsService;
      },
      link: function($scope, elem) {
        $scope.$watch('CantoBreadcrumbsService.termHistory',
                      function() {
                        $('#breadcrumbs-terms').remove();
                        var termList = CantoBreadcrumbsService.termHistory;
                        var $dest = $('#breadcrumbs-search');
                        var html = '<div id="breadcrumbs-terms">';

                        for (var i = 0; i < termList.length; i++) {
                          var termId = termList[i];
                          var makeLink = (i != termList.length - 1);

                          html += '<div class="breadcrumbs-link">' +
                            '<breadcrumb-term term-id="' + termId + '"></breadcrumb-term>';
                        }

                        for (var i = 0; i < termList.length; i++) {
                          html += '</div>';
                        }

                        html += '</div>';

                        $dest.append($compile(html)($scope));
                      });
      },
      templateUrl: app_static_path + 'ng_templates/breadcrumbs.html',
    }
  };

canto.directive('breadcrumbs', ['$compile', 'CantoBreadcrumbsService', breadcrumbsDirective]);


var breadcrumbTermDirective =
  function(CantoService) {
    return {
      scope: {
        termId: '@',
      },
      restrict: 'E',
      replace: true,
      controller: function($scope) {
        var promise = CantoService.lookup('ontology', [$scope.termId]);

        promise.success(function(data) {
          $scope.termName = data.name;
        });
      },
      templateUrl: app_static_path + 'ng_templates/breadcrumb_term.html',
    }
  };

canto.directive('breadcrumbTerm', ['CantoService', breadcrumbTermDirective]);


var featureChooser =
  function($modal, CursGeneList, CursGenotypeList, toaster) {
    return {
      scope: {
        featureType: '@',
        chosenFeatureId: '=',
      },
      restrict: 'E',
      replace: true,
      controller: function($scope) {
        function get_genes_from_server() {
          CursGeneList.geneList().then(function(results) {
            $scope.features = results;
          }).catch(function() {
            toaster.pop('note', "couldn't read the gene list from the server");
          });
        };
        if ($scope.featureType === 'gene') {
          get_genes_from_server();
        } else {
          CursGenotypeList.cursGenotypeList().then(function(results) {
            $scope.features = results;
          }).catch(function() {
            toaster.pop('note', "couldn't read the genotype list from the server");
          });
        }

        $scope.openSingleGeneAddDialog = function() {
          var modal = $modal.open({
            templateUrl: app_static_path + 'ng_templates/single_gene_add.html',
            controller: 'SingleGeneAddDialogCtrl',
            title: 'Add a new gene by name or identifier',
            animate: false,
            windowClass: "modal",
          });
          modal.result.then(function () {
            get_genes_from_server();
          });
        };
      },
      templateUrl: app_static_path + 'ng_templates/feature_chooser.html',
    }
  };

canto.directive('featureChooser', ['$modal', 'CursGeneList', 'CursGenotypeList', 'toaster', featureChooser]);

var ontologyTermLocatorCtrl =
  function($scope, CantoGlobals, AnnotationTypeConfig, CantoBreadcrumbsService, $http, $modal, toaster) {
    $scope.data = {
      termConfirmed: false,
      conditions: [],
      validEvidence: false,
    };

    $scope.openTermSuggestDialog =
      function(feature_display_name) {
        var suggestInstance = $modal.open({
          templateUrl: app_static_path + 'ng_templates/term_suggest.html',
          controller: 'TermSuggestDialogCtrl',
          title: 'Suggest a new term for ' + feature_display_name,
          animate: false,
          windowClass: "modal",
        });

        suggestInstance.result.then(function (termSuggestion) {
          $scope.data.termSuggestion = termSuggestion;
          $scope.data.termConfirmed = true;

          toaster.pop('note',
                      'Your term suggestion will be stored, but ' +
                      feature_display_name + ' will be temporarily ' +
                      'annotated with the parent of your suggested new term');
        });
      };

    $scope.confirmTerm = function() {
      $scope.data.termConfirmed = true;
    };

    $scope.unconfirmTerm = function() {
      $scope.data.termConfirmed = false;
    };

    $scope.unsetTerm = function() {
      $scope.data.term_name = '';
      $scope.data.term_ontid = '';
      CantoBreadcrumbsService.searchString = null;
      CantoBreadcrumbsService.termHistory = [];
    };

    $scope.back = function() {
      history.go(-1);
    };

    $scope.setTermAndEvidence = function() {
      simpleHttpPost(toaster, $http, '../set_term/' + $scope.annotationTypeName,
                     { term_ontid: $scope.data.term_ontid,
                       evidence_code: $scope.data.evidence_code,
                       conditions: $scope.data.conditions,
                       with_gene_id: $scope.data.with_gene_id,
                       term_suggestion: $scope.data.termSuggestion,
                     });
    };

    $scope.isValidEvidence = function() {
      return !!$scope.data.validEvidence;
    };

    $scope.isValid = function() {
      return $scope.data.termConfirmed && $scope.isValidEvidence();
    };

    $scope.init = function() {
      $scope.annotationTypeName = CantoGlobals.ferret_choose.annotation_type_name;

      AnnotationTypeConfig.getByName($scope.annotationTypeName)
        .then(function(annotationType) {
          $scope.annotationType = annotationType;
        });

      $('#loading').unbind('.canto');

      var set_term_callback = function(newValue, oldValue) {
        if (newValue !== oldValue) {
          CantoBreadcrumbsService.searchString = trim($scope.data.searchString);
          CantoBreadcrumbsService.termHistory = [newValue];
          CantoGlobals.ferret_choose.set_current_term(newValue);
          CantoGlobals.ferret_choose.matching_synonym = $scope.data.matchingSynonym;

          CantoGlobals.ferret_choose.get_term_by_id(newValue,
                                                    function(term) {
                                                      CantoGlobals.ferret_choose.render(term);
                                                    });
        }
      };

      $scope.$watch('data.term_ontid', set_term_callback);

      $("body").delegate("#ferret-term-children-list a", "click",
                         CantoGlobals.ferret_choose.child_click_handler);
      $("body").delegate("#breadcrumbs .breadcrumbs-term a", "click",
                         CantoGlobals.ferret_choose.term_click_handler);
      $("body").delegate("#breadcrumbs-search a", "click",
                         CantoGlobals.ferret_choose.term_click_handler);

      $('#ferret-term-input').attr('disabled', false);

      $('.canto-more-button').each(function (index, element) {
        var this_id = $(element).attr('id');
        var target = $('#' + this_id + '-target');
        $(element).click(
          function () {
            target.show()
            $(element).hide();
            return false;
          }
        );
        $(element).show();
      });
    };

    $scope.init();
  };

canto.controller('OntologyTermLocatorCtrl',
                 ['$scope', 'CantoGlobals', 'AnnotationTypeConfig', 'CantoBreadcrumbsService',
                  '$http', '$modal', 'toaster',
                  ontologyTermLocatorCtrl]);


var annotationEvidence =
  function(AnnotationTypeConfig, CantoConfig) {
    var directive = {
      scope: {
        evidenceCode: '=',
        conditions: '=',
        withGeneId: '=',
        validEvidence: '=', // true when evidence and with_gene_id are valid
        annotationTypeName: '@',
      },
      restrict: 'E',
      replace: true,
      controller: function($scope) {
        $scope.annotationType = '';

        AnnotationTypeConfig.getByName($scope.annotationTypeName)
          .then(function(annotationType) {
            $scope.annotationType = annotationType;
          });

        $scope.isValidEvidenceCode = function() {
          return !!$scope.evidenceCode;
        };

        $scope.isValidWithGene = function() {
          return $scope.evidenceTypes && $scope.evidenceCode &&
            (!$scope.evidenceTypes[$scope.evidenceCode].with_gene || !!$scope.withGeneId);
        };

        $scope.showWith = function() {
          return $scope.evidenceTypes && $scope.isValidEvidenceCode() &&
            $scope.evidenceTypes[$scope.evidenceCode].with_gene;
        };

        $scope.showConditions = function() {
          return $scope.isValidEvidenceCode() && $scope.annotationType.can_have_conditions;
        };

        $scope.isValidCodeAndWith = function() {
          return $scope.isValidEvidenceCode() && $scope.isValidWithGene();
        };

        $scope.validEvidence = $scope.isValidCodeAndWith();

        CantoConfig.get('evidence_types').success(function(results) {
          $scope.evidenceTypes = results;

          $scope.$watch('evidenceCode',
                        function(newType) {
                          if (!$scope.isValidEvidenceCode() ||
                              !$scope.evidenceTypes[$scope.evidenceCode].with_gene) {
                            $scope.withGeneId = undefined;
                          }

                          $scope.validEvidence = $scope.isValidCodeAndWith();
                        });
        });

        $scope.$watch('withGeneId',
                      function(newType) {
                        $scope.validEvidence = $scope.isValidCodeAndWith();
                      });

      },
      templateUrl: app_static_path + 'ng_templates/annotation_evidence.html'
    };
    return directive;
  };

canto.directive('annotationEvidence',
                ['AnnotationTypeConfig', 'CantoConfig', annotationEvidence]);

 var conditionPicker =
   function(CursConditionList, toaster) {
     var directive = {
       scope: {
         conditions: '=',
      },
      restrict: 'E',
      replace: true,
      controller: function($scope) {
        $scope.usedConditions = [];
        $scope.addCondition = function(condName) {
          // this hack stop apply() being called twice when user clicks an add
          // button
          setTimeout(function() {
            $scope.tagitList.tagit("createTag", condName);
          }, 1);
        };
      },
      templateUrl: app_static_path + 'ng_templates/condition_picker.html',
      link: function($scope, elem) {
        var $field = elem.find('.curs-allele-conditions');

        CursConditionList.conditionList().then(function(results) {
          $scope.usedConditions = results;

          var updateScopeConditions = function() {
            // apply() is needed so the scope is update when a tag is added in
            // the Tagit field
            $scope.$apply(function() {
              $scope.conditions = [];
              $field.find('li .tagit-label').map(function(index, $elem) {
                $scope.conditions.push( { name: $elem.textContent.trim() } );
              });
            });
          };

          $field.tagit({
            minLength: 2,
            fieldName: 'curs-allele-condition-names',
            allowSpaces: true,
            placeholderText: 'Type a condition ...',
            tagSource: fetch_conditions,
            autocomplete: {
              focus: ferret_choose.show_autocomplete_def,
              close: ferret_choose.hide_autocomplete_def,
            },
          });
          $.map($scope.conditions,
                function(cond) {
                  $field.tagit("createTag", cond.name);
                });

          // don't start updating until all initial tags are added
          $field.tagit({
            afterTagAdded: updateScopeConditions,
            afterTagRemoved: updateScopeConditions,
          });

          $scope.tagitList = $field;
        }).catch(function() {
          toaster.pop('error', "couldn't read the condition list from the server");
        });
      }
    };

    return directive;
  };

canto.directive('conditionPicker', ['CursConditionList', 'toaster', conditionPicker]);

var alleleNameComplete =
  function(CursAlleleList, toaster) {
    var directive = {
      scope: {
        allelePrimaryIdentifier: '=',
        alleleName: '=',
        alleleDescription: '=',
        alleleType: '=',
        geneIdentifier: '=',
      },
      restrict: 'E',
      replace: true,
      template: '<input ng-model="alleleName" type="text" class="curs-allele-name aform-control" value=""/>',
      link: function(scope, elem) {
        var processResponse = function(lookupResponse) {
          return $.map(
            lookupResponse,
            function(el) {
              return {
                value: el.name,
                allele_primary_identifier: el.uniquename,
                display_name: el.display_name,
                description: el.description,
                allele_type: el.allele_type,
                allele_expression: el.expression
              };
            });
        };
        elem.autocomplete({
          source: function(request, response) {
            CursAlleleList.alleleList(scope.geneIdentifier, request.term)
              .then(function(lookupResponse) {
                response(processResponse(lookupResponse));
              })
            .catch(function() {
              toaster.pop("failed to lookup allele of: " + scope.geneName);
            });
          },
          select: function(event, ui) {
            scope.$apply(function() {
            if (typeof(ui.item.allele_primary_identifier) === 'undefined') {
              scope.allelePrimaryIdentifier = '';
            } else {
              scope.allelePrimaryIdentifier = ui.item.allele_primary_identifier;
            }
            if (typeof(ui.item.allele_type) === 'undefined' ||
                ui.item.allele_type === 'unknown') {
              scope.type = '';
            } else {
              scope.alleleType = ui.item.allele_type;
            }
            if (typeof(ui.item.label) === 'undefined') {
              scope.alleleName = '';
            } else {
              scope.alleleName = ui.item.label;
            }
            if (typeof(ui.item.description) === 'undefined') {
              scope.alleleDescription = '';
            } else {
              scope.alleleDescription = ui.item.description;
            }
            if (typeof(ui.item.expression) === 'undefined') {
              scope.alleleExpression = '';
            } else {
              scope.alleleExpression = ui.item.allele_expresion;
            }
            });
          }
        }).data("autocomplete" )._renderItem = function(ul, item) {
          return $( "<li></li>" )
            .data( "item.autocomplete", item )
            .append( "<a>" + item.display_name + "</a>" )
            .appendTo( ul );
        };
      }
    };

    return directive;
  };

canto.directive('alleleNameComplete', ['CursAlleleList', 'toaster', alleleNameComplete]);


var alleleEditDialogCtrl =
  function($scope, $modalInstance, CantoConfig, args) {
    $scope.gene = {
      display_name: args.gene_display_name,
      systemtic_id: args.gene_systemtic_id,
      gene_id: args.gene_id
    };
    $scope.alleleData = {
      primary_identifier: '',
      name: '',
      description: '',
      type: '',
      expression: '',
      evidence: ''
    };
    $scope.env = {
    };

    $scope.name_autopopulated = false;

    $scope.env.allele_type_names_promise = CantoConfig.get('allele_type_names');
    $scope.env.allele_types_promise = CantoConfig.get('allele_types');

    $scope.env.allele_type_names_promise.then(function(response) {
      $scope.env.allele_type_names = response.data;
    });

    $scope.env.allele_types_promise.then(function(response) {
      $scope.env.allele_types = response.data;
    });

    $scope.maybe_autopopulate = function() {
      if (typeof this.current_type_config === 'undefined') {
        return '';
      }
      var autopopulate_name = this.current_type_config.autopopulate_name;
      if (typeof(autopopulate_name) === 'undefined') {
        return '';
      }

      $scope.alleleData.name =
        autopopulate_name.replace(/@@gene_display_name@@/, this.gene.display_name);
      return this.alleleData.name;
    };

    $scope.$watch('alleleData.type',
                  function(newType) {
                    $scope.env.allele_types_promise.then(function(response) {
                      $scope.current_type_config = response.data[newType];

                      if ($scope.name_autopopulated) {
                        if ($scope.name_autopopulated == $scope.alleleData.name) {
                          $scope.alleleData.name = '';
                        }
                        $scope.name_autopopulated = '';
                      }

                      $scope.name_autopopulated = $scope.maybe_autopopulate();
                      $scope.alleleData.description = '';
                    });
                  });

    $scope.isValidType = function() {
      return !!$scope.alleleData.type;
    };

    $scope.isValidName = function() {
      return !$scope.current_type_config || $scope.current_type_config.allele_name_required == 0 || $scope.alleleData.name;
    };

    $scope.isValidDescription = function() {
      return !$scope.current_type_config || $scope.current_type_config.description_required == 0 || $scope.alleleData.description;
    };

    $scope.isExistingAllele = function() {
      return !!$scope.alleleData.primary_identifier;
    };

    $scope.isValid = function() {
      return $scope.isExistingAllele() ||
        $scope.isValidType() &&
        $scope.isValidName() && $scope.isValidDescription();
      // evidence and expression if needed ...
    };

    // if (data ...) {
    //   populate_dialog_from_data(...);
    // }

    //  var name_input = $allele_dialog.find('.curs-allele-name');
    //  name_input.attr('placeholder', 'Allele name (optional)');

    // return the data from the dialog as an Object
    $scope.dialogToData = function($scope) {
      return {
        primary_identifier: $scope.alleleData.primary_identifier,
        name: $scope.alleleData.name,
        description: $scope.alleleData.description,
        type: $scope.alleleData.type,
        evidence: $scope.alleleData.evidence,
        expression: $scope.alleleData.expression,
        gene_id: $scope.gene.gene_id
      };
    };

    $scope.ok = function () {
      $modalInstance.close($scope.dialogToData($scope));
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

canto.controller('AlleleEditDialogCtrl',
                 ['$scope', '$modalInstance',
                  'CantoConfig', 'args',
                 alleleEditDialogCtrl]);

var termSuggestDialogCtrl =
  function($scope, $modalInstance) {
    $scope.suggestion = {
      name: '',
      definition: '',
    };

    $scope.isValidName = function() {
      return $scope.suggestion.name;
    };

    $scope.isValidDefinition = function() {
      return $scope.suggestion.definition;
    };

    $scope.isValid = function() {
      return $scope.isValidName() && $scope.isValidDefinition();
    };

    // return the data from the dialog as an Object
    $scope.dialogToData = function($scope) {
      return {
        name: $scope.suggestion.name,
        definition: $scope.suggestion.definition,
      };
    };

    $scope.ok = function () {
      $modalInstance.close($scope.dialogToData($scope));
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

canto.controller('TermSuggestDialogCtrl',
                 ['$scope', '$modalInstance',
                 termSuggestDialogCtrl]);


var singleGeneAddDialogCtrl =
  function($scope, $modalInstance, $q, toaster, CantoService, Curs) {
    $scope.gene = {
      searchIdentifier: '',
      message: null,
      valid: false,
    };

    $scope.isValid = function() {
      return $scope.gene.primaryIdentifier != null;
    };

    var cancelPromise = null;

    $scope.$watch('gene.searchIdentifier',
                  function() {
                    $scope.gene.message = null;
                    $scope.gene.primaryIdentifier = null;

                    if (cancelPromise != null) {
                      cancelPromise.resolve();
                      cancelPromise = null;
                    }

                    if ($scope.gene.searchIdentifier.length >= 2) {
                      cancelPromise = $q.defer();

                      var promise = CantoService.lookup('gene', [$scope.gene.searchIdentifier],
                                                        undefined, cancelPromise);

                      promise.success(function(data) {
                        if (data.missing.length > 0) {
                          $scope.gene.message = 'Not found';
                          $scope.gene.primaryIdentifier = null;
                        } else {
                          if (data.found.length > 1) {
                            $scope.gene.message =
                              'There is more than one gene matching gene: ' +
                              $.map(data.found,
                                    function(gene) {
                                      return gene.primary_identifier || gene.primary_name
                                    }).join(', ');
                            $scope.gene.primaryIdentifier = null;
                          } else {
                            $scope.gene.message = 'Found: ';

                            if (data.found[0].primary_name) {
                              $scope.gene.message +=
                                data.found[0].primary_name + '(' + data.found[0].primary_identifier + ')';
                            } else {
                              $scope.gene.message += data.found[0].primary_identifier;
                            }
                            $scope.gene.primaryIdentifier = data.found[0].primary_identifier;
                          }
                        }
                      });
                    }
                  });

    $scope.ok = function () {
      var promise = Curs.add('gene', [$scope.gene.primaryIdentifier]);

      promise.success(function(data) {
        if (data.status === 'error') {
          toaster.pop('error', data.message);
        } else {
          if (data.gene_id == null) {
            // null if the gene was already in the list
            toaster.pop('info', $scope.gene.primaryIdentifier +
                        ' is already added to this session');
          }
          $modalInstance.close({
            new_gene_id: data.gene_id,
          });
        }
      })
      .error(function() {
        toaster.pop('error', 'Failed to add gene, could not contact the Canto server');
      });
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

canto.controller('SingleGeneAddDialogCtrl',
                 ['$scope', '$modalInstance', '$q', 'toaster', 'CantoService', 'Curs',
                 singleGeneAddDialogCtrl]);

canto.controller('MultiAlleleCtrl', ['$scope', '$http', '$modal', 'CantoConfig', 'Curs', 'toaster',
                                     function($scope, $http, $modal, CantoConfig, Curs, toaster) {
  $scope.alleles = [
  ];
  $scope.genes = [
  ];

  Curs.list('gene').success(function(results) {
    $scope.genes = results;

    $.map($scope.genes,
          function(gene) {
            gene.display_name = gene.primary_name || gene.primary_identifier;
          });
  })
  .error(function() {
    toaster.pop('failed to get gene list from server');
  });

  $scope.data = {
    genotype_long_name: '',
    genotype_name: ''
  };

  $scope.env = {
    curs_config_promise: CantoConfig.get('curs_config')
  };

  $scope.$watch('alleles',
                function() {
                  $scope.env.curs_config_promise.then(function(response) {
                    $scope.data.genotype_long_name =
                      response.data.genotype_config.default_strain_name +
                      " " +
                      $.map($scope.alleles, function(val) {
                        var newName = val.name || 'no_name';
                        if (val.description === '') {
                          newName += "(" + val.type + ")";
                        } else {
                          newName += "(" + val.description + ")";
                        }
                        if (val.expression !== '') {
                          newName += "[" + val.expression + "]";
                        }
                        return newName;
                      }).join(" ");
                  });
                },
                true);

  $scope.store = function() {
    simpleHttpPost(toaster, $http, 'store',
                   { genotype_name: $scope.data.genotype_name,
                     alleles: $scope.alleles });
  };

  $scope.removeAllele = function (allele) {
    $scope.alleles.splice($scope.alleles.indexOf(allele), 1);
  };

  $scope.openAlleleEditDialog =
    function(gene_display_name, gene_systemtic_id, gene_id) {
      var editInstance = $modal.open({
        templateUrl: 'alleleEdit.html',
        controller: 'AlleleEditDialogCtrl',
        title: 'Add an allele for this phenotype',
        animate: false,
        windowClass: "modal",
        resolve: {
          args: function() {
            return {
              gene_display_name: gene_display_name,
              gene_systemtic_id: gene_systemtic_id,
              gene_id: gene_id
            };
          }
        }
      });

      editInstance.result.then(function (alleleData) {
        $scope.alleles.push(alleleData);
      });
    };

  $scope.cancel = function() {
    window.location.href = curs_root_uri + '/genotype_manage';
  };

  $scope.isValid = function() {
    return $scope.alleles.length > 0;
  };
}]);

var GenotypeManageCtrl =
  function($scope, CursGenotypeList, CantoGlobals, toaster) {
    $scope.app_static_path = CantoGlobals.app_static_path;

    $scope.data = {
      genotypeSearching: false,
      genotypes: [],
      waitingForServer: true,
    };

    $scope.startSearch = function() {
      $scope.data.genotypeSearching = true;
    };

    $scope.cancelSearch = function() {
      $scope.data.genotypeSearching = false;
    };

    CursGenotypeList.cursGenotypeList().then(function(results) {
      $scope.data.genotypes = results;
      $scope.data.waitingForServer = false;
    }).catch(function() {
      toaster.pop('error', "couldn't read the genotype list from the server");
      $scope.data.waitingForServer = false;
    });
  };

canto.controller('GenotypeManageCtrl',
                 ['$scope', 'CursGenotypeList', 'CantoGlobals', 'toaster',
                 GenotypeManageCtrl]);

var geneSelectorCtrl =
  function(CursGeneList, toaster) {
    return {
      scope: {
        selectedGenes: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/gene_selector.html',
      controller: function($scope) {
        $scope.data = {
          genes: [],
        };
      },
      link: function(scope) {
        CursGeneList.geneList().then(function(results) {
          scope.data.genes = results;
        }).catch(function() {
          toaster.pop('note', "couldn't read the gene list from the server");
        });

        scope.selectedGenesFilter = function() {
          scope.selectedGenes = $.grep(scope.data.genes, function(gene) {
            return gene.selected;
          });
        };
      },
    }
  }

canto.directive('geneSelector',
                 ['CursGeneList', 'toaster',
                  geneSelectorCtrl]);

var genotypeSearchCtrl =
  function(CursGenotypeList, CantoGlobals, toaster) {
    return {
      scope: {
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_search.html',
      controller: function($scope) {
        $scope.data = {
          filteredGenotypes: [],
          searchGenes: [],
          waitingForServer: false,
        };
        $scope.app_static_path = CantoGlobals.app_static_path;
      },
      link: function(scope) {
        scope.$watch('data.searchGenes',
                      function() {
                        if (scope.data.searchGenes.length == 0) {
                          scope.data.filteredGenotypes.length = 0;
                        } else {
                          scope.data.waitingForServer = true;
                          CursGenotypeList.filteredGenotypeList({
                            gene_identifiers: $.map(scope.data.searchGenes,
                                                    function(gene_data) {
                                                      return gene_data.primary_identifier
                                                    })
                          }).then(function(results) {
                            scope.data.filteredGenotypes = results;
                            scope.data.waitingForServer = false;
                          }).catch(function() {
                            toaster.pop('error', "couldn't read the genotype list from the server");
                            scope.data.waitingForServer = false;
                          });
                        }
                      });
      },
    }
  };

canto.directive('genotypeSearch',
                 ['CursGenotypeList', 'CantoGlobals', 'toaster',
                  genotypeSearchCtrl]);

var genotypeListRowCtrl =
  function() {
    return {
      restrict: 'A',
      replace: true,
      templateUrl: function(elem,attrs) {
        return app_static_path + 'ng_templates/genotype_list_row.html'
      },
      controller: function($scope) {
      },
    };
  };

canto.directive('genotypeListRow',
                [genotypeListRowCtrl]);


var genotypeListViewCtrl =
  function() {
    return {
      scope: {
        genotypeList: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_list_view.html',
      controller: function($scope) {

      },
    }
  };

canto.directive('genotypeListView',
                 [genotypeListViewCtrl]);


var EditDialog = function($) {
  function confirm($dialog) {
    var $form = $('#curs-edit-dialog form');
    $dialog.dialog('close');
    $('#loading').unbind('ajaxStop.canto');
    $form.ajaxSubmit({
          dataType: 'json',
          success: function() {
            $dialog.dialog("destroy");
            var $dialog_div = $('#curs-edit-dialog');
            $dialog_div.remove();
            window.location.reload(false);
          }
        });
  }

  function cancel() {
    $(this).dialog("destroy");
    var $dialog_div = $('#curs-edit-dialog');
    $dialog_div.remove();
  }

  function create(title, current_comment, form_url) {
    var $dialog_div = $('#curs-edit-dialog');
    if ($dialog_div.length) {
      $dialog_div.remove();
    }

    var dialog_html =
      '<div id="curs-edit-dialog" style="display: none">' +
      '<form action="' + form_url + '" method="post">' +
      '<textarea rows="8" cols="70" name="curs-edit-dialog-text">' + current_comment +
      '</textarea></form></div>';

    $dialog_div = $(dialog_html);

    var $dialog = $dialog_div.dialog({
      modal: true,
      autoOpen: true,
      height: 'auto',
      width: 600,
      title: title,
      buttons : [
                 {
                   text: "Cancel",
                   click: cancel,
                 },
                 {
                   text: "Edit",
                   click: function() {
                     confirm($dialog);
                   },
                 },
                ]
    });

    return $dialog;
  }

  return {
    create: create
  };
}($);

function UploadGenesCtrl($scope) {
  $scope.data = {
    geneIdentifiers: '',
    noAnnotation: false,
    noAnnotationReason: '',
    otherText: '',
    geneList: '',
  };
  $scope.isValid = function() {
    return $scope.data.geneIdentifiers.length > 0 ||
      ($scope.data.noAnnotation &&
      $scope.data.noAnnotationReason.length > 0 &&
      ($scope.data.noAnnotationReason !== "Other" ||
       $scope.data.otherText.length > 0));
  };
}

function SubmitToCuratorsCtrl($scope) {
  $scope.data = {
    reason: null,
    hasAnnotation: false
  };
  $scope.noAnnotationReasons = ['Review'];

  $scope.init = function(reasons) {
    $scope.noAnnotationReasons = reasons;
  };

  $scope.validReason = function() {
    return $scope.data.reason != null && $scope.data.reason.length > 0;
  };
}

canto.service('CantoConfig', function($http) {
  this.get = function(key) {
    return $http({method: 'GET',
                  url: canto_root_uri + 'ws/canto_config/' + key,
                  cache: true});
  };
});

canto.service('AnnotationTypeConfig', function(CantoConfig, $q) {
  this.getAll = function() {
    if (typeof(this.listPromise) === 'undefined') {
      this.listPromise = CantoConfig.get('annotation_type_list');
    }

    return this.listPromise;
  };
  this.getByKeyValue = function(key, value) {
    var q = $q.defer();

    this.getAll().success(function(annotationTypeList) {
      var filteredAnnotationTypes =
        $.grep(annotationTypeList,
               function(annotationType) {
                 return annotationType[key] === value;
               });
      if (filteredAnnotationTypes.length > 0){
        q.resolve(filteredAnnotationTypes[0]);
      } else {
        q.resolve(undefined);
      }
    }).error(function() {
      q.reject();
    });

    return q.promise;

  }
  this.getByName = function(typeName) {
    return this.getByKeyValue('name', typeName);
  };
  this.getByNamespace = function(namespace) {
    return this.getByKeyValue('namespace', namespace);
  };
});

function UploadGenesCtrl($scope) {
  $scope.data = {
    geneIdentifiers: '',
    noAnnotation: false,
    noAnnotationReason: '',
    otherText: '',
    geneList: '',
  };
  $scope.isValid = function() {
    return $scope.data.geneIdentifiers.length > 0 ||
      ($scope.data.noAnnotation &&
       $scope.data.noAnnotationReason.length > 0 &&
       ($scope.data.noAnnotationReason !== "Other" ||
        $scope.data.otherText.length > 0));
  };
}

function AlleleCtrl($scope) {
  $scope.alleles = [
  {name: 'name1', description: 'desc', type: 'type1'}
  ];
}

function SubmitToCuratorsCtrl($scope) {
  $scope.data = {
    reason: null,
    otherReason: '',
    hasAnnotation: false
  };
  $scope.noAnnotationReasons = [];

  $scope.init = function(reasons) {
    $scope.noAnnotationReasons = reasons;
  };

  $scope.validReason = function() {
    return $scope.data.reason != null && $scope.data.reason.length > 0 &&
      ($scope.data.reason !== 'Other' || $scope.data.otherReason.length > 0);
  };
}


var annotationEditDialogCtrl =
  function($scope, $modalInstance, AnnotationProxy, AnnotationTypeConfig,
           CantoConfig, toaster, args) {
    $scope.annotation = { conditions: [] };
    $scope.annotationTypeName = args.annotationTypeName;
    $scope.currentFeatureDisplayName = args.currentFeatureDisplayName;
    $scope.newlyAdded = args.newlyAdded;
    $scope.status = {
      // validEvidence: false;
    };

    copyObject(args.annotation, $scope.annotation);

    $scope.isValidFeature = function() {
      return $scope.annotation.feature_id;
    };

    $scope.isValidInteractingGene = function() {
      return $scope.annotation.interacting_gene_id;
    };

    $scope.isValidTerm = function() {
      return $scope.annotation.term_ontid;
    };

    $scope.isValidEvidence = function() {
      return $scope.status.validEvidence;
    };

    $scope.isValid = function() {
      if ($scope.annotationType.category === 'ontology') {
        return $scope.isValidFeature() &&
          $scope.isValidTerm() && $scope.isValidEvidence();
      } else {
        return $scope.isValidFeature() &&
          $scope.isValidInteractingGene() && $scope.isValidEvidence();
      }
    };

    $scope.ok = function() {
      var q = AnnotationProxy.storeChanges(args.annotation,
                                           $scope.annotation, args.newlyAdded);
      q.then(function(annotation) {
        $modalInstance.close(annotation);
      })
      .catch(function(message) {
        toaster.pop('error', message);
        $modalInstance.dismiss();
      });
    };

    $scope.cancel = function() {
      $modalInstance.dismiss('cancel');
    };

    AnnotationTypeConfig.getByName($scope.annotationTypeName)
      .then(function(annotationType) {
        $scope.annotationType = annotationType;
        $scope.displayAnnotationFeatureType = capitalize(annotationType.feature_type);
        $scope.annotation.feature_type = annotationType.feature_type;
      });
  };


canto.controller('AnnotationEditDialogCtrl',
                 ['$scope', '$modalInstance', 'AnnotationProxy',
                  'AnnotationTypeConfig', 'CantoConfig', 'toaster',
                  'args',
                  annotationEditDialogCtrl]);



function startEditing($modal, annotationTypeName, annotation, currentFeatureDisplayName, newlyAdded) {
  var editInstance = $modal.open({
    templateUrl: app_static_path + 'ng_templates/annotation_edit.html',
    controller: 'AnnotationEditDialogCtrl',
    title: 'Edit this annotation',
    animate: false,
    size: 'lg',
    resolve: {
      args: function() {
        return {
          annotation: annotation,
          annotationTypeName: annotationTypeName,
          currentFeatureDisplayName: currentFeatureDisplayName,
          newlyAdded: newlyAdded,
        };
      }
    }
  });

  return editInstance.result;
}

function makeNewAnnotation(template) {
  var copy = {};
  copyObject(template, copy);
  copy.newly_added = true;
  return copy;
}

var annotationTableCtrl =
  function($modal, AnnotationProxy, AnnotationTypeConfig, CursGenotypeList) {
    return {
      scope: {
        featureIdFilter: '@',
        featureTypeFilter: '@',
        featureStatusFilter: '@',
        featureFilterDisplayName: '@',
        annotationTypeName: '@',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/annotation_table.html',
      controller: function($scope) {
        $scope.data = {
          hasFeatures: false, // set to true if there are feature of type featureTypeFilter
          annotations: null
        };
        $scope.addNew = function() {
          var template = {
            annotation_type: $scope.annotationTypeName,
            feature_type: $scope.featureTypeFilter
          };
          if ($scope.featureIdFilter) {
            template.feature_id = $scope.featureIdFilter;
          }
          var newAnnotation = makeNewAnnotation(template);
          var editPromise =
            startEditing($modal, $scope.annotationTypeName, newAnnotation, $scope.featureFilterDisplayName, true);

          editPromise.then(function(editedAnnotation) {
            $scope.data.annotations.push(editedAnnotation);
          });
        };
      },
      link: function(scope) {
        scope.data.annotations = null;
        AnnotationProxy.getFiltered({annotationTypeName: scope.annotationTypeName,
                                     featureId: scope.featureIdFilter,
                                     featureStatus: scope.featureStatusFilter,
                                     featureType: scope.featureTypeFilter
                                    }).then(function(annotations) {
                                      scope.data.annotations = annotations;
                                    });
        AnnotationTypeConfig.getByName(scope.annotationTypeName).then(function(annotationType) {
          scope.annotationType = annotationType;
          scope.displayAnnotationFeatureType = capitalize(annotationType.feature_type);

          if (annotationType.feature_type === 'genotype') {
            CursGenotypeList.cursGenotypeList().then(function(results) {
              scope.data.hasFeatures = (results.length > 0);
            }).catch(function() {
              toaster.pop('error', "couldn't read the genotype list from the server");
            });
          } else {
            // if we're here the user has some genes in their list
            scope.data.hasFeatures = true;
          }
        });
      }
    };
  };

canto.directive('annotationTable',
                ['$modal', 'AnnotationProxy', 'AnnotationTypeConfig', 'CursGenotypeList',
                 annotationTableCtrl]);

var annotationTableList =
  function(AnnotationProxy, AnnotationTypeConfig, CantoGlobals) {
    return {
      scope: {
        featureIdFilter: '@',
        featureTypeFilter: '@',
        featureFilterDisplayName: '@',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/annotation_table_list.html',
      controller: function($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;
      },
      link: function(scope) {
        scope.annotationTypes = [];
        AnnotationTypeConfig.getAll().then(function(response) {
          scope.annotationTypes =
            $.grep(response.data,
                   function(annotationType) {
                     if (scope.featureTypeFilter === undefined ||
                         annotationType.feature_type === scope.featureTypeFilter) {
                       return annotationType;
                     }
                   });
        });
      }
    };
  };

canto.directive('annotationTableList', ['AnnotationProxy', 'AnnotationTypeConfig', 'CantoGlobals', annotationTableList]);


var annotationTableRow =
  function($modal, AnnotationProxy, AnnotationTypeConfig, CursGeneList, CantoGlobals, toaster) {
    return {
      restrict: 'A',
      replace: true,
      templateUrl: function(elem,attrs) {
        return app_static_path + 'ng_templates/annotation_table_' +
          attrs.annotationType + '_row.html'
      },
      controller: function($scope) {
        $scope.data = {};

        $scope.curs_root_uri = CantoGlobals.curs_root_uri;

        var annotation = $scope.annotation;

        if (typeof($scope.annotation.conditions) !== 'undefined') {
          $scope.annotation.conditionsString =
            conditionsToString($scope.annotation.conditions);
        }

        AnnotationTypeConfig.getByName(annotation.annotation_type)
          .then(function(annotationType) {
            $scope.annotationType = annotationType;
          });

        CursGeneList.geneList().then(function(results) {
          $scope.genes = results;

          $.map($scope.genes,
                function(gene) {
                  gene.display_name = gene.primary_name || gene.primary_identifier;
                });
        }).catch(function() {
          toaster.pop('note', "couldn't read the gene list from the server");
        });

        $scope.edit = function() {
          var editPromise =
            startEditing($modal, annotation.annotation_type, $scope.annotation, undefined, false);

          editPromise.then(function(editedAnnotation) {
            $scope.annotation = editedAnnotation;
            if (typeof($scope.annotation.conditions) !== 'undefined') {
              $scope.annotation.conditionsString =
                conditionsToString($scope.annotation.conditions);
            }
          });
        };
        $scope.duplicate = function() {
          var newAnnotation = makeNewAnnotation($scope.annotation);
          var editPromise = startEditing($modal, annotation.annotation_type,
                                         newAnnotation, undefined, true);

          editPromise.then(function(editedAnnotation) {
            var index = $scope.data.annotations.indexOf($scope.annotation);
            $scope.data.annotations.splice(index + 1, 0, editedAnnotation);
          });
        };
        $scope.delete = function() {
          bootbox.confirm("Are you sure?", function(confirmed) {
            if (confirmed) {
              AnnotationProxy.deleteAnnotation(annotation)
                .then(function() {
                  arrayRemoveOne($scope.annotations, annotation);
                })
                .catch(function(message) {
                  toaster.pop('note', "couldn't delete the annotation: " + message);
                });
            }
          });
        };
      },
    };
  };

canto.directive('annotationTableRow',
                ['$modal', 'AnnotationProxy', 'AnnotationTypeConfig',
                 'CursGeneList', 'CantoGlobals', 'toaster',
                 annotationTableRow]);


var termNameComplete =
  function($timeout) {
    return {
      scope: {
        annotationTypeName: '@',
        currentTermName: '@',
        foundTermId: '=',
        foundTermName: '=',
        searchString: '=',
        matchingSynonym: '=',
      },
      controller: function($scope) {
        $scope.render_term_item =
          function(ul, item, search_string) {
            var searchAnnotationTypeName = $scope.annotationTypeName;
            var search_bits = search_string.split(/\W+/);
            var match_name = item.matching_synonym;
            var synonym_extra = '';
            if (match_name) {
              synonym_extra = ' (synonym)';
            } else {
              match_name = item.name;
            }
            var warning = '';
            if (searchAnnotationTypeName !== item.annotation_type_name) {
              warning = '<br/><span class="autocomplete-warning">WARNING: this is the ID of a ' +
                item.annotation_type_name + ' term but<br/>you are browsing ' +
                search_namespace + ' terms</span>';
              var re = new RegExp('_', 'g');
              // unpleasant hack to make the namespaces look nicer
              warning = warning.replace(re,' ');
            }
            function length_compare(a,b) {
              if (a.length < b.length) {
                return 1;
              } else {
                if (a.length > b.length) {
                  return -1;
                } else {
                  return 0;
                }
              }
            };
            search_bits.sort(length_compare);
            for (var i = 0; i < search_bits.length; i++) {
              var bit = search_bits[i];
              if (bit.length > 1) {
                var re = new RegExp('(\\b' + bit + ')', "gi");
                match_name = match_name.replace(re,'<b>$1</b>');
              }
            }
            return $( "<li></li>" )
              .data( "item.autocomplete", item )
              .append( "<a>" + match_name + " <span class='term-id'>(" +
                       item.id + ")</span>" + synonym_extra + warning + "</a>" )
              .appendTo( ul );
          };
      },
      replace: true,
      restrict: 'E',
      template: '<input size="40" type="text" class="form-control" value="{{currentTermName}}"/>',
      link: function(scope, elem) {
        elem.autocomplete({
          minLength: 2,
          source: make_ontology_complete_url(scope.annotationTypeName),
          cacheLength: 100,
          focus: ferret_choose.show_autocomplete_def,
          close: ferret_choose.hide_autocomplete_def,
          select: function(event, ui) {
            $timeout(function() {
              scope.foundTermId = ui.item.id;
              scope.foundTermName = ui.item.value;
              scope.searchString = elem.val();
              scope.matchingSynonym = ui.item.matching_synonym;
            }, 1);
          },
        }).data("autocomplete")._renderItem = function( ul, item ) {
          var search_string = elem.val();
          return scope.render_term_item(ul, item, search_string);
        };
        elem.attr('disabled', false);

        function do_autocomplete (){
          elem.focus();
          scope.$apply(function() {
            elem.autocomplete('search');
          });
        }

        elem.bind('paste', function() {
          setTimeout(do_autocomplete, 10);
        });

        elem.keypress(function(event) {
          if (event.which == 13) {
            // return should autocomplete not submit the form
            event.preventDefault();
            do_autocomplete();
          }
        });
      }
    };
  };

canto.directive('termNameComplete', ['$timeout', termNameComplete]);
