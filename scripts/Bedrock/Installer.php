<?php

namespace Bedrock;

use Composer\Script\Event;

class Installer {

  public static $base_dir;

  public static $env_vars = array(
    'WP_ENV' => array(
      'default'  => 'development',
      'question' => 'Environment',
    ),
    'WP_LOCAL_DEV' => array(
      'default'  => true,
      'question' => 'Is this a local environment?',
      'yesno'    => true,
    ),
    'DOMAIN_CURRENT_SITE' => array(
      'default'  => array(__CLASS__, '_getDirName'),
      'question' => '(Main site) Domain Name',
    ),
    'DOMAIN_NAMES' => array(
      'default'  => array(__CLASS__, '_getEnvValue'),
      'args'     => 'DOMAIN_CURRENT_SITE',
      'question' => 'Domain Names (for multisite)',
    ),
    'DB_NAME' => array(
      'default'   => array(__CLASS__, '_getEnvValue'),
      'args'      => 'DOMAIN_CURRENT_SITE',
      'question'  => 'Database Name',
      'validator' => array(__CLASS__, 'stripNonAlphaNumerics'),
    ),
    'DB_USER' => array(
      'default'   => 'wp',
      'question'  => 'Database User',
      'validator' => array(__CLASS__, 'stripNonAlphaNumerics'),
    ),
    'DB_PASSWORD' => array(
      'default'  => 'wp',
      'question' => 'Database Password',
    ),
    'DB_HOST' => array(
      'default'  => 'localhost',
      'question' => 'Database Host',
    ),
    'TABLE_PREFIX' => array(
      'default'   => 'wp_',
      'question'  => 'Table Prefix',
      'validator' => array(__CLASS__, 'stripNonAlphaNumerics'),
    ),
  );

  public static $salt_keys = array(
    'AUTH_KEY',
    'SECURE_AUTH_KEY',
    'LOGGED_IN_KEY',
    'NONCE_KEY',
    'AUTH_SALT',
    'SECURE_AUTH_SALT',
    'LOGGED_IN_SALT',
    'NONCE_SALT'
  );

  public static function createEnv(Event $event) {
    self::$base_dir = dirname(dirname(__DIR__));
    $default_filename = '.env';
    $filename = getenv('ENV_FILE');
    $composer = $event->getComposer();
    $io = $event->getIO();

    if (!$io->isInteractive()) {
      if (empty($filename)) {
        $filename = $default_filename;
      }

      array_walk(
        self::$env_vars,
        function(&$props, $key) {
          $value = self::_getDefault($props, true);
          $props = $value;
        }
      );
    }
    else {
      if (empty($filename)) {
        $filename = $io->askAndValidate(
          sprintf('Filename to write environment variables to [<comment>%s</comment>]:', $default_filename),
          function ($string, $x = 0) {
            if(!preg_match('#^[\w\._-]+$#i', $string)) {
              throw new \RunTimeException( 'The filename can only contains alphanumerics, dots, and underscores' );
            }
            return $string;
          },
          false,
          $default_filename
        );
      }

      $io->write(sprintf('<info>Generating <comment>"%s"</comment> file</info>', $filename));
      foreach (self::$env_vars as $key => $props) {
        $default = self::_getDefault($props);
        if (!empty($props['yesno'])) {
          $value = $io->askConfirmation(sprintf('%s [<comment>Y,n</comment>]: ', $props['question']), $default);
        }
        else {
          $value = $io->ask(sprintf('%s [<comment>%s</comment>]: ', $props['question'], $default), $default);
        }
        self::$env_vars[$key] = self::_validate($value, $props);
      }
    }

    self::$env_vars['WP_HOME']    = sprintf('http://%s', self::$env_vars['DOMAIN_CURRENT_SITE']);
    self::$env_vars['WP_SITEURL'] = sprintf('%s/wp', self::$env_vars['WP_HOME']);

    foreach (self::$salt_keys as $key) {
      self::$env_vars[$key] = self::generate_salt();
    }

    if(0 === strpos($filename, '/')) {
      $env_file = $filename;
    }
    else {
      $env_file = sprintf('%s/%s', self::$base_dir, $filename);
    }
    $env_vars = array();
    foreach (self::$env_vars as $key => $value) {
      $env_vars[] = sprintf("%s='%s'", $key, $value);
    }
    $env_vars = implode("\n", $env_vars) . "\n";

    try {
      file_put_contents($env_file, $env_vars, LOCK_EX);
      $io->write(sprintf('<info><comment>%s</comment> successfully created.</info>', $filename));
    } catch (\Exception $e) {
      $io->write('<error>An error occured while creating your .env file. Error message:</error>');
      $io->write(sprintf('<error>%s</error>%s', $e->getMessage(), "\n"));
      $io->write('<info>Below is the environment variables generated:</info>');
      $io->write($env_vars);
    }
  }

  /**
   * Slightly modified/simpler version of wp_generate_password
   * https://github.com/WordPress/WordPress/blob/cd8cedc40d768e9e1d5a5f5a08f1bd677c804cb9/wp-includes/pluggable.php#L1575
   */
  public static function generate_salt($length = 64) {
    $chars  = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    $chars .= '!@#$%^&*()';
    $chars .= '-_ []{}<>~`+=,.;:/?|';

    $salt = '';
    for ($i = 0; $i < $length; $i++) {
      $salt .= substr($chars, rand(0, strlen($chars) - 1), 1);
    }

    return $salt;
  }

  public static function stripNonAlphaNumerics($string) {
    return preg_replace('/[^a-zA-Z0-9_]+/', '_', $string);
  }

  private static function _getDirName() {
    return basename(self::$base_dir);
  }

  private static function _getDefault(Array $props, $validate = true) {
    if (is_callable($props['default'])) {
      if (empty($props['args'])) {
        $props['args'] = array();
      }
      $props['default'] = call_user_func_array($props['default'], (array)$props['args']);
      if ($validate) {
        $props['default'] = self::_validate($props['default'], $props);
      }
    }

    return $props['default'];
  }

  private static function _getEnvValue($key) {
    if (isset(self::$env_vars[$key])) {
      return self::$env_vars[$key];
    }

    return false;
  }

  private static function _validate($value, Array $props) {
    if (!empty($props['validator']) && is_callable($props['validator'])) {
      $value = call_user_func_array($props['validator'], (array)$value);
      if (empty($value)) {
        $value = self::_getDefault($props);
      }
    }

    return $value;
  }
}
