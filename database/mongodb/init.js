/* Run on first boot by the official image. Does not enable TTL or seed raw events. */
const fs = require('fs');
const events = db.getSiblingDB('culturepick_events');
const validator = JSON.parse(fs.readFileSync(process.env.CULTUREPICK_SCHEMA_FILE || '/opt/culturepick/event_schema.json', 'utf8'));
if (events.getCollectionNames().includes('raw_events')) {
  events.runCommand({collMod: 'raw_events', validator, validationLevel: 'strict', validationAction: 'error'});
} else {
  events.createCollection('raw_events', {validator, validationLevel: 'strict', validationAction: 'error'});
}
if (!events.getCollectionNames().includes('rejected_events')) {
  events.createCollection('rejected_events', {validator: {$jsonSchema: {
    bsonType: 'object', additionalProperties: false,
    required: ['reject_id', 'received_at', 'reason_code', 'sanitized_payload'],
    properties: {_id: {bsonType: 'objectId'}, reject_id: {bsonType: 'string'}, received_at: {bsonType: 'date'},
      reason_code: {enum: ['INVALID_SCHEMA', 'EVENT_ID_CONFLICT', 'PAYLOAD_TOO_LARGE']}, sanitized_payload: {bsonType: 'object'}}
  }}, validationLevel: 'strict', validationAction: 'error'});
}
events.raw_events.createIndex({event_id: 1}, {unique: true, name: 'uq_event_id'});
events.raw_events.createIndex({user_id: 1, occurred_at: -1}, {name: 'ix_user_time'});
events.raw_events.createIndex({event_type: 1, occurred_at: -1}, {name: 'ix_type_time'});
events.raw_events.createIndex({request_id: 1}, {name: 'ix_request'});
events.raw_events.createIndex({operation_id: 1}, {name: 'ix_operation'});
events.raw_events.createIndex({received_at: 1, event_id: 1}, {name: 'ix_received_checkpoint'});
events.rejected_events.createIndex({reject_id: 1}, {unique: true, name: 'uq_reject_id'});
events.rejected_events.createIndex({received_at: 1}, {name: 'ix_rejected_received'});
events.rejected_events.createIndex({reason_code: 1}, {name: 'ix_rejected_reason'});

const definitions = [
  ['event_append', [{resource: {db: events.getName(), collection: 'raw_events'}, actions: ['find', 'insert']},
    {resource: {db: events.getName(), collection: 'rejected_events'}, actions: ['find', 'insert']}]],
  ['outbox_append', [{resource: {db: events.getName(), collection: 'raw_events'}, actions: ['find', 'insert']}]]
];
for (const [role, privileges] of definitions) {
  if (!events.getRole(role)) events.createRole({role, privileges, roles: []});
}
const accounts = [
  ['MONGO_APP_PASSWORD', 'event_app', [{role: 'event_append', db: events.getName()}]],
  ['MONGO_DISPATCHER_PASSWORD', 'event_dispatcher', [{role: 'outbox_append', db: events.getName()}]],
  ['MONGO_ANALYTICS_PASSWORD', 'event_analytics', [{role: 'read', db: events.getName()}]],
  ['MONGO_BACKUP_PASSWORD', 'event_backup', [{role: 'read', db: events.getName()}]]
];
for (const [variable, user, roles] of accounts) {
  const pwd = process.env[variable];
  if (!pwd || pwd.startsWith('replace-')) throw new Error(`Set a private random value for ${variable}`);
  if (!events.getUser(user)) events.createUser({user, pwd, roles});
}
