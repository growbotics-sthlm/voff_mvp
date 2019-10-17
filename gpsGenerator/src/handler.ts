'use strict'

import { DynamoDB } from 'aws-sdk'

const dynamoDb = new DynamoDB.DocumentClient()

export const handler = (event, context, callback) => {
  console.log('-------------------------------')
  const timestamp = new Date().toISOString()
  const data = JSON.parse(event.body)
  console.log(data)

  const params = {
    TableName: 'VoffGPS',
    Item: {
      id: '2388990e-89ba-48c2-a7bf-b1e896b45865',
      created: timestamp,
      lat: data.lat,
      lon: data.lon,
      alt: data.alt
    }
  }

  // write the todo to the database
  dynamoDb.put(params, (error, result) => {
    // handle potential errors
    if (error) {
      console.error(error)
      callback(new Error('Couldn\'t create the todo item.'))
      return
    }

    // create a response
    const response = {
      statusCode: 200,
      body: JSON.stringify(params)
    }
    callback(null, response)
  })
}
