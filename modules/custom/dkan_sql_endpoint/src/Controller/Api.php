<?php

namespace Drupal\dkan_sql_endpoint\Controller;

use Drupal\Core\Config\ConfigFactoryInterface;
use Drupal\dkan_datastore\Service\Datastore;
use Drupal\dkan_datastore\Storage\DatabaseTable;
use Drupal\dkan_datastore\Storage\Query;
use Drupal\Core\DependencyInjection\ContainerInjectionInterface;
use Maquina\StateMachine\MachineOfMachines;
use SqlParser\SqlParser;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Drupal\Core\Database\Connection;

/**
 * Api class.
 */
class Api implements ContainerInjectionInterface {

  private $database;
  private $datastore;
  private $configFactory;

  /**
   * Inherited.
   *
   * @{inheritdocs}
   *
   * @codeCoverageIgnore
   */
  public static function create(ContainerInterface $container) {
    return new Api($container->get('database'), $container->get('dkan_datastore.service'), $container->get('config.factory'));
  }

  /**
   * Constructor.
   */
  public function __construct(Connection $database, Datastore $datastore, ConfigFactoryInterface $configFactory) {
    $this->database = $database;
    $this->datastore = $datastore;
    $this->configFactory = $configFactory;
  }

  /**
   * Method called by the router.
   */
  public function runQuery($query_string) {

    $parser = new SqlParser();

    if ($parser->validate($query_string) === FALSE) {
      return $this->response("Invalid query string.", 500);
    }

    $state_machine = $parser->getValidatingMachine();

    try {
      $query_object = $this->getQueryObject($state_machine);
    }
    catch (\Exception $e) {
      return $this->response("No datastore.", 500);
    }

    $databaseTable = new DatabaseTable($this->database, $this->getResource($state_machine));

    try {
      $result = $databaseTable->query($query_object);
    }
    catch (\Exception $e) {
      $this->response("Querying a datastore that does not exist.", 500);
    }

    return $this->response($result, 200);

  }

  /**
   * Private.
   */
  private function getResource(MachineOfMachines $state_machine) {
    $uuid = $this->getUuidFromSelect($state_machine->gsm('select')->gsm('table_var'));
    return $this->datastore->getResourceFromUuid($uuid);
  }

  /**
   * Private.
   */
  private function getQueryObject($state_machine) {
    $object = new Query();
    $this->setQueryObjectSelect($object, $state_machine->gsm('select'));
    $this->setQueryObjectWhere($object, $state_machine->gsm('where'));
    $this->setQueryObjectOrderBy($object, $state_machine->gsm('order_by'));
    $this->setQueryObjectLimit($object, $state_machine->gsm('limit'));

    return $object;
  }

  /**
   * Private.
   */
  private function setQueryObjectSelect(Query $object, $state_machine) {
    $strings = $this->getStringsFromStringMachine($state_machine->gsm('select_count_all'));
    if (!empty($strings)) {
      $object->count();
      return;
    }

    $strings = $this->getStringsFromStringMachine($state_machine->gsm('select_var_all'));
    if (!empty($strings)) {
      return;
    }

    $strings = $this->getStringsFromStringMachine($state_machine->gsm('select_var'));
    foreach ($strings as $property) {
      $object->filterByProperty($property);
    }
  }

  /**
   * Private.
   */
  private function setQueryObjectWhere(Query $object, $state_machine) {
    $properties = $this->getStringsFromStringMachine($state_machine->gsm('where_column'));
    $values = $this->getStringsFromStringMachine($state_machine->gsm('quoted_string')->gsm('string'));

    foreach ($properties as $index => $property) {
      $value = $values[$index];
      if ($value) {
        $object->conditionByIsEqualTo($property, $value);
      }
    }
  }

  /**
   * Private.
   */
  private function setQueryObjectOrderBy(Query $object, $state_machine) {
    $properties = $this->getStringsFromStringMachine($state_machine->gsm('order_var'));

    $direction = $this->getStringsFromStringMachine($state_machine->gsm('order_asc'));
    if (!empty($direction)) {
      foreach ($properties as $property) {
        $object->sortByAscending($property);
      }
    }
    else {
      foreach ($properties as $property) {
        $object->sortByDescending($property);
      }
    }
  }

  /**
   * Private.
   */
  private function setQueryObjectLimit(Query $object, $state_machine) {
    $rows_limit = $this->configFactory->get('dkan_sql_endpoint.settings')->get('rows_limit');

    $limit = $this->getStringsFromStringMachine($state_machine->gsm('numeric1'));
    if (!empty($limit) && $limit[0] <= $rows_limit) {
      $object->limitTo($limit[0]);
    }
    else {
      $object->limitTo($rows_limit);
    }

    $offset = $this->getStringsFromStringMachine($state_machine->gsm('numeric2'));
    if (!empty($offset)) {
      $object->offsetBy($offset[0]);
    }
  }

  /**
   * Private.
   */
  private function getUuidFromSelect($machine) {
    $strings = $this->getStringsFromStringMachine($machine);
    if (empty($strings)) {
      throw new \Exception("No UUID given");
    }
    return $strings[0];
  }

  /**
   * Private.
   */
  private function getStringsFromStringMachine($machine) {
    $strings = [];
    $current_string = "";
    $array = $machine->execution;

    foreach ($array as $states_or_input) {
      if (is_array($states_or_input)) {
        $states = $states_or_input;
        if (in_array(0, $states) && !empty($current_string)) {
          $strings[] = $current_string;
          $current_string = "";
        }
      }
      else {
        $input = $states_or_input;
        $current_string .= $input;
      }
    }

    if (!empty($current_string)) {
      $strings[] = $current_string;
    }

    return $strings;
  }

  /**
   * Private.
   */
  private function response($message, $code) {
    return new JsonResponse(
        $message,
        $code,
        ["Access-Control-Allow-Origin" => "*"]
      );
  }

}
