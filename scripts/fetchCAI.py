'''Cloud Function module to export data for a given day.

This module is designed to be plugged in a Cloud Function, attached to Cloud
Scheduler trigger to create a Cloud Asset Inventory Export to BigQuery.

'''

import base64
import datetime
import json
import logging
import os
import warnings

import click

from google.api_core.exceptions import GoogleAPIError
from google.cloud import asset_v1

import googleapiclient.discovery
import googleapiclient.errors


def _configure_logging(verbose=True):
  '''Basic logging configuration.
  Args:
    verbose: enable verbose logging
  '''
  level = logging.DEBUG if verbose else logging.INFO
  logging.basicConfig(level=level)
  warnings.filterwarnings('ignore', r'.*end user credentials.*', UserWarning)


@click.command()
@click.option('--project', required=True, help='Project ID')
@click.option('--bq-project', required=True, help='Bigquery project to use.')
@click.option('--bq-dataset', required=True, help='Bigquery dataset to use.')
@click.option('--bq-table', required=True, help='Bigquery table name to use.')
@click.option('--read-time', required=False, help=(
    'Day to take an asset snapshot in \'YYYYMMDD\' format, uses current day '
    ' as default. Export will run at midnight of the specified day.'))
@click.option('--verbose', is_flag=True, help='Verbose output')
@click.option('--asset_type', required=True, help='Name of the asset type EG: • ["compute.googleapis.com/Instance"].')
def main_cli(project=None, bq_project=None, bq_dataset=None, bq_table=None,
             read_time=None, verbose=False, asset_types=None):
  '''Trigger Cloud Asset inventory export to Bigquery. Data will be stored in
  the dataset specified on a dated table with the name specified.
  '''
  try:
    _main(project, bq_project, bq_dataset, bq_table, read_time, verbose, asset_types)
  except RuntimeError:
    logging.exception('exception raised')


def main(event, context):
  'Cloud Function entry point.'
  try:
    data = json.loads(base64.b64decode(event['data']).decode('utf-8'))
    print(data)
    _main(**data)
  # uncomment once https://issuetracker.google.com/issues/155215191 is fixed
  # except RuntimeError:
  #  raise
  except Exception:
    logging.exception('exception in cloud function entry point')


def _main(project=None, bq_project=None, bq_dataset=None, bq_table=None, read_time=None, verbose=False, asset_types=None):
  'Module entry point used by cli and cloud function wrappers.'

  _configure_logging(verbose)
  if not read_time:
    read_time = datetime.datetime.now()
  client = asset_v1.AssetServiceClient()
  # 2021-12-02 best practice is to keep a BQ export per project, but in our case we need export of * in org => specific project
  # parent = 'projects/%s' % project
  parent = 'organizations/1043105805686'
  content_type = asset_v1.ContentType.RESOURCE
  output_config = asset_v1.OutputConfig()
  output_config.bigquery_destination.dataset = 'projects/%s/datasets/%s' % (
      bq_project, bq_dataset)
# 2021-12-02 Replace to below to keep history
#   output_config.bigquery_destination.table = '%s_%s' % (
#      bq_table, read_time.strftime('%Y%m%d'))
  output_config.bigquery_destination.table = '%s_latest' % (
      bq_table)
  output_config.bigquery_destination.force = True
  output_config.bigquery_destination.separate_tables_per_asset_type = True
  try:
    response = client.export_assets(
        request={
            'parent': parent,
            'read_time': read_time,
            'content_type': content_type,
            'output_config': output_config,
            'asset_types'  : asset_types
        }
       )
  except (GoogleAPIError, googleapiclient.errors.HttpError) as e:
    logging.debug('API Error: %s', e, exc_info=True)
    raise RuntimeError(
        'Error fetching Asset Inventory entries (project: %s)' % parent, e)


if __name__ == '__main__':
  main_cli()
